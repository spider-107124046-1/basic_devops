To create a Bash-based tool named vault_sweeper that can:

1. Recursively scan specified directories for sensitive or malformed environment files.
2. Validate and sanitize the contents of these files based on security constraints.
3. Create a directory called logs/ and add the respective logs in it. Create a user called maintainer and ensure the directory can be accessed only by the same.
4. Collect and log metadata such as file user, permissions, ACLs, and modification details inside the logs/ directory.
5. Generate secure output files from valid data.

### File Discovery and Validation

1. File Discovery:

    * Take one directory path as input.
    * Go through all files and folders inside it (including hidden files), checking them one by one.
    * Look for environment files (`.env`, `.env.example`, etc.).

2. Validation and Sanitization:

    * Check each line in the environment files.
    * Keep only the valid environment variables.
    * Remove lines that are unsafe or incorrectly written.

3. Rules for Validation:

    Valid Lines (Keep these):

    * `API_KEY=validkey123` # No spaces around `=`, only letters/numbers/underscores in key
    * `SAFE_ONE=value1` # Correct format
    * `DEBUG=false` # Correct format

    Invalid Lines (Reject these):

    * `PASSWORD = secret123` # Space around equals sign
    * `SERVER-NAME=web01` # Hyphen in variable name
    * `export PATH=$PATH:/tmp` # Modifies PATH variable
    * `USER_EMAIL="admin@example"` # Unnecessary quotes
    * `LOG_LEVEL= info` # Space after equals sign

    Reject any key like PASSWORD, SECRET, TOKEN, or any key that modifies system variables like PATH

4. Metadata and Logging:

    Capture and log the following in metadata.log file inside the logs directory made earlier:
    
    * File path
    * User, permissions
    * ACLs and extended attributes
    * Number of valid/invalid lines
    * Identity of last modifier
    * Rejected lines

    Example: metadata.log
    ```
    File: /path/to/repo/.env
    User: UID=1001 (user1), GID=1001 (group1)
    Permissions: 0644
    Valid Lines: 3
    Invalid Lines: 5
    Rejected Lines:
        PASSWORD = secret123
        SERVER-NAME=web01
        export PATH=$PATH:/tmp
        USER_EMAIL="admin@example"
        LOG_LEVEL= info
    ```
### Output

* Store sanitized variables in a secure environment file named .env.sanitized.
* Save all logs and metadata in a separate metadata.log file.
* Ensure proper file permissions and ownership.

### Example Secure Environment File:

* `API_KEY=validkey123`
* `SAFE_ONE=value1`
* `DEBUG=false`

### Bonus Task

* Detect and log files with SUID, SGID, sticky bit, or extended attributes.
* Prompt the user whether to lock down sanitized files.
* Set up a scheduled cronjob with a scan script that sends an alert to a specific user when issues are detected.

Example Suspicious File Detection:

* Warning: File `/path/to/repo/.env` has world-writable permissions (`0666`)
* Warning: File `/path/to/repo/config.sh` has execute permissions (`0755`)

Deliverables

* A script that implements all requirements
* Sample input files (malformed and valid)
* Generated secure output and log files under a vault/ directory
