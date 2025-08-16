variable FPM_VERSION { default = "1.16.0" }

variable images {
  default = [
    "debian:11",
    "debian:12",
    "fedora:42",
    "rockylinux/rockylinux:9",
    "rockylinux/rockylinux:10",
    "ubuntu:22.04",
    "ubuntu:24.04",
    "almalinux:9",
    "almalinux:10",
    "amazonlinux:2023",
    #"quay.io/centos/centos:stream10",
    #"quay.io/centos/centos:stream9",
    
    # TODO: Do builds for older distros? Like rocky 8 has ruby 2.5,
    # but fpm depends on dotenv which requires ruby 3
    # "rockylinux:8", ships ruby 2.5, and dotenv requires Ruby>3.0
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