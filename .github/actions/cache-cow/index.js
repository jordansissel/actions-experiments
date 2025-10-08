import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as fs from "node:fs/promises";
import * as path from "path";

class Cow {
  constructor(paths) {
    this.base = "/overlay";
    this.root = path.join(this.base, "_");
    this.mounts = [];
    this.paths = paths;
  }

  async setup() {
    await this.#tmpfs(this.base);
    await this.#mkdirP(this.root);


    await this.#rootSymlinks();
    await this.paths.forEach(async source_path => await this.#overlay(source_path))
  }

  async teardown() {
    this.mounts.reverse().forEach(async mount => {
      await this.#sudo("umount", [mount]);
    });
  }

  async #rootSymlinks() {
    const toplevel = await fs.readdir("/", { "withFileTypes": true })
    await exec.exec("ls", ["-l", this.root]);

    toplevel.forEach(async dirent => {
      if (dirent.isSymbolicLink()) {
        const target = await fs.readlink(path.join(dirent.parentPath, dirent.name));
        console.log(`Creating symlink in overlay (${this.root}/${dirent.name}) pointing to ${target}`);

        await fs.symlink(target, path.join(this.root, dirent.name));
      }
    });
  }

  async #sudo(command, args, options = {}) {
    const cmd = [command].concat(args)
    return exec.exec("sudo", cmd, options)
  }

  async #mkdirP(path) {
    return this.#sudo("mkdir", ["-p", path]);
  }

  async #tmpfs(mount_point) {
    await this.#mkdirP(mount_point);
    await this.#sudo("mount", ["-t", "tmpfs", "none", mount_point]);

    this.mounts.append(mount_point);
  }

  async #overlay(source_path) {
    const lower = source_path;
    const upper = path.join(this.base, "upper", source_path);
    const work = path.join(this.base, "work", source_path);
    const mount_point = path.join(this.root, source_path)

    await this.#mkdirP(upper);
    await this.#mkdirP(work);
    await this.#mkdirP(mount_point);

    const opts = `lowerdir=${lower},upperdir=${upper},workdir=${work}`
    await this.#sudo("mount", ["-t", "overlay", "none", "-o", opts, mount_point]);
    this.mounts.append(mount_point);
  }
} // Cow

function main() {
  //if (process.getuid() !== 0) {
  //console.log("Rerunning as root");
  //process.env["RUNNER_USER"] = process.getuid();
  //return exec.exec("sudo", ["-E", process.execPath].append(process.execArgv))
  //}

  const paths = ["/usr", "/etc", "/var/lib"];
  const cow = new Cow(paths);
  cow.setup()
  exec.exec("mount | grep /overlay");

  console.log("Script: ", core.getInput("run"));
  cow.teardown()
}

try {
  main();
} catch (error) {
  core.setFailed(error.message);
}
