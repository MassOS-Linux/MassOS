# Building MassOS
If you're a developer, you may wish to compile the MassOS system yourself. This guide shows you how to use the scripts in this repo to do so.

**Important: Most users won't want to compile MassOS themselves. The [releases page](https://github.com/TheSonicMaster/MassOS/releases) has the latest released version precompiled, and can be installed simply using the [installation guide](installation-guide.md).**
# Important Notes (READ BEFORE ATTEMPTING TO COMPILE)
- The second part of the build (Stage 2) needs **ROOT ACCESS**. This is because it uses a chroot environment. Fakeroot is not supported.
- Building MassOS is no quick task. The build speed will vary massively depending on your CPU. The fastest CPUs will take no longer than a few hours to compile MassOS, however the build could take **several days** on slower systems. The majority of the build process cannot be paused and resumed later, therefore **ensure you have enough time available**.
# How to build MassOS
### Clone the repo:
```
git clone https://github.com/TheSonicMaster/MassOS.git
cd MassOS
```
By default, you will build the stable version of MassOS. If you instead want to build the *development version*, which contains unreleased changes which are being developed for the next version of MassOS, check out the "development" branch with the following command:
```
git checkout development
```
**NOTE: The development branch is UNSTABLE. It's not guaranteed to even successfully compile at all. If you're a first time builder, we recommend the stable version first.**
### Retrieve the sources:
```
./retrieve-sources.sh
```
**NOTE: Ensure everything downloaded successfully. If the final message says something along the lines of "Some downloads may have failed", then you MUST NOT continue until all downloaded were successful. You can re-run the retrieve-sources.sh script, and it will not re-download any existing files, it will only try to download the missing files again.**
### Build the temporary bootstrap system:
```
./stage1.sh
```
### Build the full MassOS system:
```
sudo ./stage2.sh
```
### Finishing up:
When the MassOS system is completely build and finished, an output tarball labelled `massos-<VERSION>-rootfs-x86_64.tar.xz` will be created. **It is highly recommended that you change ownership of the final output tarball back to the original user. You can do this with the following commands:**
```
non_root_user=$(whoami)
sudo chown $non_root_user:$non_root_user massos-$(cat utils/massos-release)-rootfs-x86_64.tar.xz
unset non_root_user
```
You can then use this tarball to install MassOS following the installation guide.
