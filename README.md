# KentAVR Firmware Project

Use this repository to start a new or to add a ready-to-build KentAVR project to an existing Git repository.

## Create a project

1. Open a folder in the Git repository where the firmware should live. If it is a new repository, initialize Git first. Commit or stash existing changes before continuing.

   ```bash
   cd /path/to/your-project
   ```

2. Clone this repository:

   ```bash
   git clone https://github.com/kentavr-platform/kentavr-project.git Firmware
   ```

3. Run the bootstrap script:

   ```bash
   cd Firmware
   bash Scripts/new-project.sh
   ```

4. Follow the instructions on the screen.

