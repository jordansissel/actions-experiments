variable FPM_VERSION { default = "1.16.0" }

variable images {
  default = [
    "debian:11",
    "debian:12",
    "fedora:42",
    "ubuntu:22.04",
    "ubuntu:24.04",
    "almalinux:8",
    "almalinux:9",
    "almalinux:10",
    "rockylinux/rockylinux:8",
    "rockylinux/rockylinux:9",
    "rockylinux/rockylinux:10",
    "quay.io/centos/centos:stream8",
    "quay.io/centos/centos:stream9",
    "quay.io/centos/centos:stream10",
    "amazonlinux:2023",
  ]
}

target "prepare" {
  matrix = { image = images }
  target = "prepare"
  name = "prepare-${replace(replace(replace(image, ":", "-"), ".", "_"), "/", "_")}"
  
  args = {
    IMAGE = "${image}"
    FPM_VERSION = "${FPM_VERSION}"
  }

  tags = [
    "${image}-prepare"
  ]
}

target "default" {
  name = "fpm-${replace(replace(replace(image, ":", "-"), ".", "_"), "/", "_")}"

  matrix = { image = images }

  args = {
    IMAGE = "${image}"
    FPM_VERSION = "${FPM_VERSION}"
  }

  contexts = {
    prepare = "target:prepare-${replace(replace(replace(image, ":", "-"), ".", "_"), "/", "_")}"
  }

  tags = [
    "fpm:${FPM_VERSION}-${replace(replace(replace(image, ":", "-"), ".", "_"), "/", "_")}"
  ]
}

target "repotool" {
  context = "../repo"

  tags = [
    "fpm-repotool:latest"
  ]
}