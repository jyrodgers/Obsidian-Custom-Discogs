# Setup

```shell
#!/bin/bash
#
# Setup
#
# Setup the Custom Discogs vault with markdown from the user Discogs collection
# or a local music library using the Discogs API to retrieve artist/album info

URL="https://api.discogs.com"
AGE="github.com/doctorfree/MusicPlayerPlus"
LOCAL=
UPD=
VAULT=

[ -x Tools/Discogs/mkdiscogs ] || {
  echo "Tools/Discogs/mkdiscogs does not exist or is not executable."
  echo "The Setup script must be run in the Obsidian-Custom-Discogs folder."
  echo "Exiting without performing custom setup."
  exit 1
}

# Get the Discogs username and a Discogs API token
[ -f "${HOME}/.config/mpprc" ] && . "${HOME}/.config/mpprc"

usage() {
  printf "Usage: ./Setup [-L /path/to/library] [-A] [-f foldername] [-v vault] [-R] [-U] [-t token] [-u user] [-ehnqr]"
  printf "\nWhere:"
  printf "\n\t-A indicates add existing vault folder releases to a Discogs collection"
  printf "\n\t\tVault folder is specified with '-v vault'"
  printf "\n\t\tVault folder previously created with './Setup -L /path/to/library'"
  printf "\n\t\tCan be used with '-f foldername' to specify collection folder"
  printf "\n\t-R indicates remove items from specified Discogs collection folder"
  printf "\n\t\tMust be accompanied by '-f foldername'"
  printf "\n\t-L 'path' indicates use a local music library rather than Discogs collection"
  printf "\n\t-U indicates perform an update of the Discogs collection"
  printf "\n\t-f 'foldername' specifies the Discogs collection folder name to use."
  printf "\n\t\tOnly used in conjunction with '-A' (add releases to Discogs collection)."
  printf "\n\t\tIf no folder by this name exists, one will be created."
  printf "\n\t\tDefault: Uncategorized"
  printf "\n\t-e displays example usage and exits"
  printf "\n\t-n indicates perform a dry run (only used in conjunction with '-A')"
  printf "\n\t-q indicates quiet mode (only used in conjunction with '-A')"
  printf "\n\t-r indicates remove intermediate JSON created during previous run"
  printf "\n\t-t 'token' specifies the Discogs API token"
  printf "\n\t-u 'user' specifies the Discogs username"
  printf "\n\t-v 'vault' specifies the folder name for generated artist/album markdown"
  printf "\n\t-h displays this usage message and exits\n"
  exit 1
}

examples() {
  printf "\nExample invocations:"
  printf "\n\t# Retrieve Discogs collection"
  printf "\n\t# Generated markdown in capitalized Discogs username folder"
  printf "\n\t./Setup"
  printf "\n\t# Generated markdown in 'Discogs' folder"
  printf "\n\t./Setup -v Discogs"
  printf "\n\t# Retrieve Discogs user 'foobar' collection"
  printf "\n\t./Setup -u foobar"
  printf "\n\t# Retrieve Discogs data for local music library in /u/audio"
  printf "\n\t./Setup -L /u/audio -v Audio"
  printf "\n\t# Provide Discogs username and API token on command line"
  printf "\n\t./Setup -L ~/Music -u doctorfree -t xyzkdkslekjrelrkek"
  printf "\n\t# Retrieve Discogs data for genre local music library in /u/jazz"
  printf "\n\t./Setup -L /u/jazz -v Jazz"
  printf "\n\t# Add existing vault releases to Discogs collection folder"
  printf "\n\t# From a previously generated run of './Setup -L /path/to/library'"
  printf "\n\t# Perform a dry run:"
  printf "\n\t./Setup -n -A -f MyMusic -v Music_Library"
  printf "\n\t# Add releases from Music_Library folder to Discogs collection MyMusic:"
  printf "\n\t./Setup -A -f MyMusic -v Music_Library"
  printf "\n\t# Delete releases in MyMusic Discogs collection folder:"
  printf "\n\t./Setup -R -f MyMusic\n"
  exit 1
}

check_username() {
  curl --stderr /dev/null \
       -A "${AGE}" "${URL}/users/$1" | \
       grep "User does not exist" > /dev/null && {
           DISCOGS_USER=
       }
}

check_token() {
  curl --stderr /dev/null \
       -A "${AGE}" \
       -H "Authorization: Discogs token=$1" \
       "${URL}/users/${username}" | \
       grep "Invalid consumer token" > /dev/null && {
           DISCOGS_TOKEN=
       }
}

get_username() {
  numtries=1
  while true
  do
    read -p "Discogs username: " username
    case ${username} in
      [?]* )
          DISCOGS_USER="${username}"
          check_username "${username}"
          if [ "${DISCOGS_USER}" ]
          then
            break
          else
            numtries=$((numtries + 1))
            [ ${numtries} -gt 3 ] && {
              echo "Too many failed attempts to set Discogs username. Exiting."
              exit 1
            }
            echo "Discogs user ${username} does not exist. Please try again."
          fi
          ;;
        * ) echo "Please enter a username."
          ;;
    esac
  done
}

get_token() {
  numtries=1
  while true
  do
    read -p "Discogs API token: " token
    case ${token} in
      [?]* )
          DISCOGS_TOKEN="${token}"
          check_token "${token}"
          if [ "${DISCOGS_TOKEN}" ]
          then
            break
          else
            numtries=$((numtries + 1))
            [ ${numtries} -gt 3 ] && {
              echo "Too many failed attempts to set Discogs API token. Exiting."
              exit 1
            }
            echo "Invalid Discogs API token: ${token}. Please try again."
          fi
          ;;
        * ) echo "Please enter a Discogs API token."
          ;;
    esac
  done
}

add2discogs=
cleanup=
dryrun=
foldername=
quiet=
remove=
while getopts "AL:RUf:t:u:v:ehnqr" flag; do
    case $flag in
        A)
            add2discogs=1
            ;;
        f)
            foldername="$OPTARG"
            ;;
        n)
            dryrun="-n"
            ;;
        q)
            quiet="-q"
            ;;
        L)
            LOCAL="${OPTARG}"
            [ -d "${OPTARG}" ] || {
              echo "Directory specified with '-L /path/to/library', ${OPTARG},"
              echo "does not exist or is not a directory."
              echo "Exiting without generating markdown."
              usage
            }
            ;;
        r)
            cleanup=1
            ;;
        R)
            remove=1
            ;;
        U)
            UPD="-U"
            ;;
        t)
            DISCOGS_TOKEN="${OPTARG}"
            ;;
        u)
            DISCOGS_USER="${OPTARG}"
            ;;
        v)
            VAULT="${OPTARG}"
            ;;
        e)
            examples
            ;;
        h)
            usage
            ;;
    esac
done
shift $(( OPTIND - 1 ))

[ "${add2discogs}" ] && [ "${LOCAL}" ] && {
  echo "-A and -L cannot be used together."
  echo "-A (add to Discogs collection) is only supported after a previous run with -L"
  echo "First perform \"./Setup -L ${LOCAL}\""
  echo "After that succeeds then perform './Setup -A ...'"
  echo "Exiting"
  exit 1
}
[ "${add2discogs}" ] && [ "${remove}" ] && {
  echo "-A and -R cannot be used together."
  echo "-A indicates \"add to Discogs collection\", -R indicates remove from collection"
  echo "Exiting"
  exit 1
}
[ "${remove}" ] && [ "${LOCAL}" ] && {
  echo "-R and -L cannot be used together."
  echo "-R (remove from Discogs collection) is only supported after a previous run with -A"
  echo "First perform \"./Setup -L ${LOCAL}\""
  echo "After that succeeds then perform './Setup -A ...'"
  echo "After that succeeds then perform './Setup -R ...' to remove items added with -A"
  echo "Exiting"
  exit 1
}

[ "${cleanup}" ] && {
  echo "Cleaning up any previously created JSON used in generating markdown"
  rm -rf Tools/Discogs/json
  exit 0
}

have_curl=`type -p curl`
have_jq=`type -p jq`

[ "${have_curl}" ] || {
  printf "\nThe 'curl' utility is required but not found in this user's execution path."
  printf "\nVerify that 'curl' is installed and available on this system, add it to PATH,"
  printf "\nor install 'curl'. On most Linux systems 'curl' can be installed with either:"
  printf "\n\tsudo apt install curl"
  printf "\nor"
  printf "\n\tsudo dnf install curl"
  printf "\nOn Mac OS 'curl' can be installed with Homebrew:"
  printf "\n\tbrew install curl\n"
}
[ "${have_jq}" ] || {
  printf "\nThe 'jq' utility is required but not found in this user's execution path."
  printf "\nVerify that 'jq' is installed and available on this system, add it to PATH,"
  printf "\nor install 'jq'. On most Linux systems 'jq' can be installed with either:"
  printf "\n\tsudo apt install jq"
  printf "\nor"
  printf "\n\tsudo dnf install jq"
  printf "\nOn Mac OS 'jq' can be installed with Homebrew:"
  printf "\n\tbrew install jq\n"
}

[ "${have_jq}" ] && [ "${have_curl}" ] || {
  printf "\nSystem requirements not met. Exiting without performing setup.\n"
  exit 1
}

if [ "${DISCOGS_USER}" ]
then
  check_username "${DISCOGS_USER}"
  [ "${DISCOGS_USER}" ] || {
    printf "\nDiscogs username found in ~/.config/mpprc appears to be invalid.\n"
    get_username
  }
else
  printf "\nDiscogs username required but none found in ~/.config/mpprc"
  printf "\nThe Discogs username can be found by visiting discogs.com. Login then"
  printf "\nuse the dropdown of your user icon in the upper right corner. Click on"
  printf "\n'Profile'. Your Discogs username is the last component of the profile URL."
  printf "\nPlease enter your Discogs username.\n"
  get_username
fi

if [ "${DISCOGS_TOKEN}" ]
then
  check_token "${DISCOGS_TOKEN}"
  [ "${DISCOGS_TOKEN}" ] || {
    printf "\nDiscogs API token found in ~/.config/mpprc appears to be invalid.\n"
    get_token
  }
else
  printf "\nDiscogs API token not found in ~/.config/mpprc"
  printf "\nLogin to discogs.com and visit:\n"
  printf "\n\thttps://www.discogs.com/settings/developers\n"
  printf "\nto find or generate a Discogs API token.\n"
  printf "\nPlease enter a Discogs API token.\n"
  get_token
fi

cd Tools/Discogs
if [ "${LOCAL}" ]
then
  [ "${VAULT}" ] || VAULT="Music_Library"
  if [ -x search-albums-markdown ]
  then
    ./search-albums-markdown \
        -t "${DISCOGS_TOKEN}" \
        -u "${DISCOGS_USER}" \
        -v "${VAULT}" "${LOCAL}"
  else
    echo "Tools/Discogs/search-albums-markdown is not found or not executable."
    echo "Exiting without generating markdown."
    exit 1
  fi
  if [ -x artists2markdown ]
  then
    ./artists2markdown -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" -v "${VAULT}"
  else
    echo "Tools/Discogs/artists2markdown is not found or not executable."
    echo "No artist markdown generated for artists in ${LOCAL}."
  fi
  ./mkdiscogs -A -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" -v "${VAULT}"
  ./mkdiscogs -d -T -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" -v "${VAULT}"
else
  if [ "${add2discogs}" ]
  then
    ./albums2discogs -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" \
                     -v "${VAULT}" -f "${foldername}" ${dryrun} ${quiet}
  else
    if [ "${remove}" ]
    then
      ./albums2discogs -r -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" \
                       -f "${foldername}" ${dryrun} ${quiet}
    else
      ./mkdiscogs -a -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" ${UPD} -v "${VAULT}"
    fi
  fi
fi
```
