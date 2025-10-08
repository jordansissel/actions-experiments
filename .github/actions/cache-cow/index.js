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
    await this.#exec("ls", ["-l", this.root]);

    toplevel.forEach(async dirent => {
      if (dirent.isSymbolicLink()) {
        const target = await fs.readlink(path.join(dirent.parentPath, dirent.name));
        console.log(`Creating symlink in overlay (${this.root}/${dirent.name}) pointing to ${target}`);

        //await fs.symlink(target, path.join(this.root, dirent.name));
        await this.#sudo("ln", ["-s", target, path.join(this.root, dirent.name)]);
      }
    });
  }

  async #exec(command, args, options) {
    console.log(`exec: ${[command].concat(args).join(" ")}`);
    return Promise.resolve()
    //return await exec.exec(command, args, options = {})
  }

  async #sudo(command, args, options = {}) {
    const cmd = [command].concat(args)
    return await this.#exec("sudo", cmd, options)
  }

  async #mkdirP(path) {
    return await this.#sudo("mkdir", ["-p", path]);
  }

  async #tmpfs(mount_point) {
    await this.#mkdirP(mount_point);
    await this.#sudo("mount", ["-t", "tmpfs", "none", mount_point]);

    this.mounts.push(mount_point);
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
    await this.#sudo("mount", ["-t", "overlay", "overlay", "-o", opts, mount_point]);
    this.mounts.push(mount_point);
  }
} // Cow

async function main() {
  //if (process.getuid() !== 0) {
  //console.log("Rerunning as root");
  //process.env["RUNNER_USER"] = process.getuid();
  //return this.#exec("sudo", ["-E", process.execPath].push(process.execArgv))
  //}

  const paths = ["/usr", "/etc", "/var/lib"];
  const cow = new Cow(paths);
  await cow.setup()
  await this.#exec("sh", ["-c", "mount | grep /overlay; true"]);

  console.log("Script: ", core.getInput("run"));
  await cow.teardown()
}

try {
  await main();
} catch (error) {
  console.log("Failed :(");
  exec.exec("sudo", ["dmesg"]);
  core.setFailed(error.message);
}
