variable FPM_VERSION { default = "1.16.0" }

variable images {
  default = [
    "debian:11",
    "debian:12",
    "fedora:42",
    # "rockylinux:8", ships ruby 2.5, and dotenv requires Ruby>3.0
    "rockylinux:9",
    "ubuntu:22.04",
    "ubuntu:24.04",
  ]
}

target "prepare" {
  matrix = { image = images }
  target = "prepare"
  name = "prepare-${replace(replace(image, ":", "-"), ".", "_")}"
  
  args = {
    IMAGE = "${image}"
    FPM_VERSION = "${FPM_VERSION}"
  }

  tags = [
    "${image}-prepare"
  ]
}

target "default" {
  name = "fpm-${replace(replace(image, ":", "-"), ".", "_")}"

  matrix = { image = images }

  args = {
    IMAGE = "${image}"
    FPM_VERSION = "${FPM_VERSION}"
  }

  contexts = {
    prepare = "target:prepare-${replace(replace(image, ":", "-"), ".", "_")}"
  }

  tags = [
    "fpm:${FPM_VERSION}-${replace(replace(image, ":", "-"), ".", "_")}"
  ]
}