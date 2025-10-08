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

    for (const source_path of this.paths) {
      await this.#overlay(source_path);
    }

    for (s of ["/tmp", "/dev", "/dev/pts", "/dev/console", "/var/cache", "/etc/resolv.conf"]) {
      const p = path.join(this.root, s);
      if (s === "/tmp") {
        await this.#mkdirP(p);
        await this.#sudo("chmod", [p, "1777"])
      } else if (s === "/dev") {
        await this.#bind(s, p)
      } else if (s === "/dev/pts") {
        await this.#bind(s, p)
      } else if (s === "/dev/console") {
        try {
          // Bind /dev/console if it exists.
          await fs.lstat(s)
          await this.#bind(s, p)
        } catch {
          // ignore
        }
      } else if (s === "/var/cache") {
        await this.#bind(s, p)
      } else if (s === "/etc/resolv.conf") {
        const resolv = await fs.lstat(s);
        const etc = await fs.lstat("/etc");
        if (etc.dev !== resolv.dev) {
          // Inside docker, /etc/resolv.conf is often mounted from the outside.
          await this.#bind(s);
        } elseif(resolv.isSymbolicLink()) {
          // Mount the linked location. Probably /run/systemd/resolv/stub-resolv.conf
          const link = await fs.readlink(resolv);
          await this.#mkdirP(path.join(this.root, path.basename(link)));

          // For a single file bind mount, the file must exist... so let's create it.
          const fd = await fs.open(path.join(this.root, link), "a");
          await fd.close()
          await this.#bind(link, path.join(this.root, link));
        }
      }
    }

    await this.#rootSymlinks();
  }

  async teardown() {
    for (const mount of this.mounts.reverse()) {
      await this.#sudo("umount", [mount]);
    };
  }

  async #rootSymlinks() {
    const toplevel = await fs.readdir("/", { "withFileTypes": true })
    await this.#exec("ls", ["-l", this.root]);

    for (const dirent of toplevel) {
      if (dirent.isSymbolicLink()) {
        const target = await fs.readlink(path.join(dirent.parentPath, dirent.name));
        console.log(`Creating symlink in overlay (${this.root}/${dirent.name}) pointing to ${target}`);

        //await fs.symlink(target, path.join(this.root, dirent.name));
        await this.#sudo("ln", ["-s", target, path.join(this.root, dirent.name)]);
      }
    };
  }

  #exec(command, args, options) {
    console.log(`exec: ${[command].concat(args).join(" ")}`);
    //return Promise.resolve()
    return exec.exec(command, args, options = {})
  }

  async #sudo(command, args, options = {}) {
    const cmd = [command].concat(args)
    await this.#exec("sudo", cmd, options)
  }

  async #mkdirP(path) {
    await this.#sudo("mkdir", ["-p", path]);
  }

  async #bind(source_path) {
    const mount_point = path.join(this.root, source_path)
    await this.#sudo("mount", ["-t", "bind", source_path, mount_point])
    this.mounts.push(mount_point);
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

  console.log("Script: ", core.getInput("run"));

  await cow.teardown()
}

try {
  await main();
} catch (error) {
  console.log("Failed :(");
  console.log(error);
  //exec.exec("sudo", ["dmesg"]);
  core.setFailed(error.message);
}
