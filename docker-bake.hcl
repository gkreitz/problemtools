variable "TAG" {
    default = "develop"
    validation {
        condition = TAG == regex("^develop|v[0-9.]+$", TAG)
        error_message = "The variable 'TAG' must be a version number, or 'develop'"
    }
}

variable "PLATFORM" {
    default = "all"
}

group "all" {
    targets = ["minimal", "icpc", "full", "githubci"]
}

target "_matrix" {
    name = "${tgt}"
    matrix = {
        tgt = ["minimal", "icpc", "full", "githubci"]
    }
    dockerfile = "Dockerfile"
    tags = [
        "problemtools/${tgt}:${TAG}",
        notequal(TAG, "develop") ? "problemtools/${tgt}:latest" : ""
    ]
    target = tgt
    context = "."
    args = {
        GITTAG = notequal(TAG, "develop") ? TAG : "master",
        BUILDKIT_CONTEXT_KEEP_GIT_DIR = 1
    }
    platforms = equal(PLATFORM, "all") ? ["linux/amd64", "linux/arm64"] : [PLATFORM]
}
