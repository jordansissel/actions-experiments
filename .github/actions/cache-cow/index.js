import * as core from "@actions/core";
import * as exec from "@actions/exec";
//import * as github from "@actions/github";

class Cow {
  constructor(paths) {
    this.base = "/overlay";
    this.root = path.join(this.base, "_");
    this.mounts = [];
    this.paths = paths;

    this.#setup();
  }

  async #setup() {
    this.#tmpfs(this.base);

    this.#rootSymlinks();
    this.paths.forEach(source_path => this.#overlay(source_path))
  }

  async #rootSymlinks() {
    //find / -maxdepth 1 -type l -print0 | xargs -0 sh -c 'cp -d "$@" /overlay/_/' -
  }

  async #tmpfs(mount_point) {
    await io.mkdirP(mount_point);
    await exec.exec("mount", ["-t", "tmpfs", "none", mount_point]);

    this.mounts.append(mount_point);
  }

  async #overlay(source_path) {
    const lower = source_path;
    const upper = path.join(this.base, "upper", source_path);
    const work = path.join(this.base, "work", source_path);
    const mount_point = path.join(this.root, source_path)

    await io.mkdirP(upper);
    await io.mkdirP(work);
    await io.mkdirP(mount_point);

    const opts = `lowerdir=${lower},upperdir=${upper},workdir=${work}`
    exec.exec("mount", ["-t", "overlay", "none", "-o", opts, mount_point]);
    this.mounts.append(mount_point);
  }

  await
} // Cow

function main() {
  // Create overlay root directory
  //const cow = new Cow()
}

try {
  //main();
  console.log(process.env);
} catch (error) {
  core.setFailed(error.message);
}
