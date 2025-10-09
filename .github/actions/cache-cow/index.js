import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as cache from "@actions/cache";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as crypto from "node:crypto";

class Cow {
  constructor(paths, script) {
    this.base = "/overlay";
    this.root = path.join(this.base, "_");
    this.mounts = [];
    this.paths = paths;

    this.script = script;

    const key = crypto.createHash("sha256")
    key.update(script);
    key.end();

    // XXX: Make cache key configurable?
    this.cache_key = `cache-cow-${key.digest('hex')}`
  }

  async run() {
    // restoreCache checks for GITHUB_SERVER_URL anyway, then retries for
    // whatever reason if it's not present... skip that :)
    if ("GITHUB_SERVER_URL" in process.env) {
      const restore = await cache.restoreCache(["cow.tar.xz"], this.cache_key);
      if (restore !== undefined) {
        console.log(`Extracting COW... (Cache COW hit on key ${restore})`);

        await this.#sudo("tar", [ "-Jvxf", "cow.tar.xz", "-C", "/" ]);
        return
      }
    }

    await this.#setup()

    try {
      await this.#runShell();

      await this.#capture();
    } catch (error) {
      console.error("Script failed", error);
      core.setFailed(error.message);
    }

    await this.#teardown()
  }

  async #setup() {
    await this.#tmpfs(this.base);
    await this.#mkdirP(this.root);

    for (const source_path of this.paths) {
      await this.#overlay(source_path);
    }

    for (const s of ["/tmp", "/run", "/proc", "/dev", "/dev/pts", "/dev/console", "/var/cache", "/var/log", "/etc/resolv.conf"]) {
      const p = path.join(this.root, s);
      if (s === "/tmp") {
        await this.#mkdirP(p);
        await this.#sudo("chmod", ["1777", p])
      } else if (s === "/proc") {
        await this.#mkdirP(p);
        await this.#sudo("mount", ["-t", "proc", "proc", p])
        this.mounts.push(p);
      } else if (s === "/run") {
        await this.#mkdirP(p);
      } else if (s === "/dev") {
        await this.#bind(s, p)
      } else if (s === "/dev/pts") {
        await this.#bind(s, p)
      } else if (s === "/dev/console") {
        try {
          // Bind /dev/console if it exists.
          await fs.lstat(s) // throws exception if /dev/console doesn't exist, that's ok.
          await this.#bind(s, p)
        } catch {
          // ignore
        }
      } else if (s === "/var/cache") {
        await this.#bind(s, p)
      } else if (s === "/var/log") {
        await this.#mkdirP(p);
      } else if (s === "/etc/resolv.conf") {
        const resolv = await fs.lstat(s);
        const etc = await fs.lstat("/etc");
        if (etc.dev !== resolv.dev) {
          // Inside docker, /etc/resolv.conf is often mounted from the outside.
          await this.#bind(s);
        } else if (resolv.isSymbolicLink()) {
          // /etc/resolv.conf is a symlink. Let's mount the linked location. It's probably /run/systemd/resolv/stub-resolv.conf
          const link = await fs.realpath(s);
          await this.#bind(link, path.join(this.root, link));
        } else {
          throw new Error(`Bug: Unexpected path when performing setup: ${s}`);
        }
      }
    }

    await this.#rootSymlinks();
  }

  async #teardown() {
    for (const mount of this.mounts.reverse()) {
      await this.#sudo("umount", [mount]);
    };
  }

  async #runShell() {
    const userspec = [process.getuid(), process.getgid()].join(":")

    let action_path = "GITHUB_ACTION_PATH" in process.env ? process.env["GITHUB_ACTION_PATH"] : import.meta.dirname;

    // Try to speed things up by removing package processes which are unnecessary on short-lived CI workers.
    // Such as: manpage db updates, package docs, etc.
    console.log("> Configuring apt/dpkg to reduce work (no manpage database, less docs/manpage files)")
    await this.#sudo("bash", ["-x", path.join(action_path, "no-docs.sh"), "setup"]);

    console.log("Running script given as `run` input");
    await this.#sudo("chroot", ["--userspec", userspec, this.root, "bash", "-ex"], { input: this.script, silent: false });
  }

  async #capture() {
    await this.#sudo("tar", [ "-Jcf", "cow.tar.xz", "-C", path.join(this.base, "upper"), "." ]);

    // restoreCache checks for GITHUB_SERVER_URL anyway, then retries for
    // whatever reason if it's not present... skip that :)
    if ("GITHUB_SERVER_URL" in process.env) {
      console.log("Uploading captured changes to the cache.");
      await cache.saveCache(["cow.tar.xz"], this.cache_key);
    }
  }

  async #rootSymlinks() {
    const toplevel = await fs.readdir("/", { "withFileTypes": true })
    await this.#exec("ls", ["-l", this.root]);

    for (const dirent of toplevel) {
      if (dirent.isSymbolicLink()) {
        const target = await fs.readlink(path.join(dirent.parentPath, dirent.name));
        //console.log(`Creating symlink in overlay (${this.root}/${dirent.name}) pointing to ${target}`);

        //await fs.symlink(target, path.join(this.root, dirent.name));
        await this.#sudo("ln", ["-s", target, path.join(this.root, dirent.name)]);
      }
    };
  }

  #exec(command, args, options) {
    if (options === undefined) {
      options = {}
    }

    if (!("silent" in options)) {
      // Default silent = true unless RUNNER_DEBUG is in env
      options.silent = !("RUNNER_DEBUG" in process.env);
    }

    //console.log(`exec: ${[command].concat(args).join(" ")}`);
    //return Promise.resolve()
    return exec.exec(command, args, options)
  }

  async #sudo(command, args, options) {
    const cmd = [command].concat(args)
    await this.#exec("sudo", cmd, options)
  }

  async #mkdirP(path) {
    await this.#sudo("mkdir", ["-p", path]);
  }

  async #bind(source_path) {
    const mount_point = path.join(this.root, source_path)
    const source = await fs.lstat(source_path);

    if (source.isDirectory()) {
      await this.#mkdirP(mount_point);
    } else {
      await this.#mkdirP(path.join(this.root, path.dirname(source_path)));

      // For a single file bind mount, the file must exist... so let's create it.
      // Use sudo here to use root permissions
      await this.#sudo("touch", [mount_point])
    }

    await this.#sudo("mount", ["--bind", source_path, mount_point])
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
  const paths = ["/usr", "/etc", "/var/lib"];
  const cow = new Cow(paths, core.getInput("run"));
  cow.run();
}

try {
  await main();
} catch (error) {
  console.log("Failed :(");
  console.log(error);
  //exec.exec("sudo", ["dmesg"]);
  core.setFailed(error.message);
}
