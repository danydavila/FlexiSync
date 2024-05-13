# FlexiSync - Sync Shell Utility

This shell script utility provides a simple and flexible way to synchronize files between local and remote locations. It supports both "push" and "pull" operations to and from local and remote directories. The script also includes a `--dry-run` feature for previewing the synchronization without making any actual changes.


## Usage

The general syntax for running the script is:

```bash
./sync.sh [config_name] [push|pull] [remote|local] [run]
```

### Commands and Options

- `config_name`: Specifies the configuration profile to use.
- `push | pull`: Determines the direction of the synchronization:
  - `push`: Send files from the local system to the remote system.
  - `pull`: Retrieve files from the remote system to the local system.
- `remote | local`: Specifies the target environment:
  - `remote`: Target is a remote system.
  - `local`: Target is the local system.
- `run`: Optional. Execute the synchronization process. If omitted, the script will perform a dry run (`--dry-run`).

## Examples

### Synchronize Local to Remote

- **Preview Mode**:
  Perform a trial run to see what changes would be made without actually applying them.

  ```bash
  ./sync.sh config_name push remote
  ```

- **Execute Sync**:
  Run the synchronization process.

  ```bash
  ./sync.sh config_name push remote run
  ```

### Synchronize Remote to Local

- **Preview Mode**:
  Simulate the execution of a sync without making any changes.

  ```bash
  ./sync.sh config_name pull remote
  ```

- **Execute Sync**:
  Run the synchronization process.

  ```bash
  ./sync.sh config_name pull remote run
  ```

### Synchronize Local to Local

- **Preview Mode**:
  Preview the synchronization between local directories.

  ```bash
  ./sync.sh config_name push local
  ./sync.sh config_name pull local
  ```

- **Execute Sync**:
  Run the synchronization process.

  ```bash
  ./sync.sh config_name push local run
  ./sync.sh config_name pull local run
  ```

## Getting Started

1. Clone the repository to your local machine.
3. create a sync profile in `config/enabled` folder.

   ```
   cp -v config/enabled/example.conf config/enabled/my-backup-to-nas.conf
   ```

4. Configure your synchronization profiles `my-backup-to-nas.conf` in the script settings according to your needs.
5. Use the commands to start syncing your files.

   ```
	 ./sync.sh my-backup-to-nas push remote
   ```

## Execute Script Within a Pipeline
An example of a GitHub Actions workflow.

	name: Sync repo to remote
	
	on:
	  push:
	    branches:
	      - release-production
	
	jobs:
	  deploy:
	    runs-on: ubuntu-latest
	    steps:
	    - name: Checkout code
	      uses: actions/checkout@v2
	
	    - name: Clone FlexiSync repository
	      run: |
	        git clone --depth=1 https://github.com/danydavila/FlexiSync.git
	
	    - name: Setup SSH
	      run: |
	        mkdir -p ~/.ssh
	        echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
	        chmod 600 ~/.ssh/id_rsa
	        ssh-keyscan -H "${{ secrets.SSH_HOSTNAME_IP }}" >> ~/.ssh/known_hosts
	        chmod 644 ~/.ssh/known_hosts
	
	    - name: Rsync files
	      run: |
	      export SRC_BASEPATH="git_repo/dist/";
	      export REMOTE_DEST_HOSTNAME="${{ secrets.SSH_USERNAME }}";
	      export REMOTE_DEST_USERNAME="${{ secrets.SSH_HOSTNAME_IP }}";
	      export REMOTE_DEST_PORT=22;
	      export REMOTE_DEST_IDENTITYKEY=~/.ssh/id_rsa
	      export REMOTE_DEST_BASEPATH="/var/www/public";
	      export DEST_BASEPATH="${REMOTE_DEST_BASEPATH}";
	      export PUSH_BACKUPLIST_PATH="cicd_git_repo/files_to_push_list.txt";
	      export PUSH_EXCLUTIONLIST_PATH="cicd_git_repo/ignore_files_list.txt";
	      export PULL_BACKUPLIST_PATH="cicd_git_repo/files_to_push_list.txt";
	      export PULL_EXCLUTIONLIST_PATH="cicd_git_repo/ignore_files_list.txt";
	      bash `pwd`/FlexiSync/sync.sh cli-config push remote run

## Contribution

Contributions to improve the script or fix issues are welcome. Please submit a pull request or open an issue if you have suggestions or encounter problems.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.