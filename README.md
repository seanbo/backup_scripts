# backup_scripts

## Descrition
A simple backup application to backup data on your linux machine and store them on a remote path.

## Requires
- tar
- Samba share for remote storage
- jq for JSON processing

# Configuration File

## The Main Configuration
The configuration, currently, only supports one configuration.  Please see "main" in the code sample below.

## "main" log definition
There are five options for the "log" node
- directory : This is the path to where the logs will be stored locally
-file_prefix : prefix for the log file's name
-file_format : This is added after "$file_prefix-", the sample provides a date format
-file_suffix : the files extension with no dot
-keep : Number of log file versions to keep stored locally

## "main" backup definition
There are two options for the "backup" node
-local_directory : Path to local storage for tar files
-shared_directory : Path to the SAMBA share for remote storage

## Targets
This is where you configure individual backup sets.  The same demonstrates backing up /boot, /etc, and a home folder.

## target definition
Targets have 8 options. 7 are required, the 8th, "exclude" is optional.
-name : name of the target, this is used as the prefix for tar files.
-directory : Path of the folder to backup
-file_format : This is added after "$file_prefix-", the sample provides a date format
-file_suffix : the files extension with no dot
-owner : After the backup is complete, the file's ownership will be changed to the specified user
-group : After the backup is complete, the file's ownership will be changed to the specified group
-keep : Number of tar file versions to keep stored locally
-exclude : This is another node used to exclude files or directories. See below

### Excludes
The exclude node will include a folders or files node (not currently implemented)
-node title "some folder name" will have a "path" identifier indicating the subdirectory path underneath the "directory" for the target.  This entire folder will be excluded.  See sample below for excclusions for /home/seanbo/backups and /home/seanbo/foo
-from_file : specify absolute path to tar style exclude pattern file

## Sample
```json
{
    "main": {
        "log": {
            "directory": "/path/to/log/files",
            "file_prefix": "backup",
            "file_format": "%Y%m%d%H%M%S",
            "file_suffix": "log",
            "keep": "44"
        },
        "backup": {
            "local_directory": "/path/to/backup/files",
            "shared_directory": "/path/to/remote/storage/location"
        }
	},
    "targets": {
        "boot": {
            "name": "boot",
            "directory": "/boot",
            "file_format": "%Y%m%d%H%M%S",
            "file_suffix": "tgz",
            "owner": "root",
            "group": "root",
            "keep": "3"
        },
        "etc": {
            "name": "etc",
            "directory": "/etc",
            "file_format": "%Y%m%d%H%M%S",
            "file_suffix": "tgz",
            "owner": "root",
            "group": "root",
            "keep": "8"
        },
        "seanbo" : {
            "name": "seanbo",
            "directory": "/home/seanbo",
            "file_format": "%Y%m%d%H%M%S",
            "file_suffix": "tgz",
            "owner": "userid",
            "group": "groupid",
            "keep": "32",
            "exclude": {
                "from_file": "/home/seanbo/backup.exclude"
                "folders": {
                    "backups": {
                        "path": "backups"
                    },
                    "foo": {
                        "path": "foo"
                    }
                }
            }
        }
    }
}
```
