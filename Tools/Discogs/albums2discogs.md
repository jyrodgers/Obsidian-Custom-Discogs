# albums2discogs

```shell
#!/bin/bash
#
# albums2discogs - written by Ronald Joe Record <ronaldrecord@gmail.com>
#
# Add albums to a Discogs collection folder
#
# Add a release to a collection folder:
# POST /users/{username}/collection/folders/{folder_id}/releases/{release_id}
#    folder_id 1 us "Uncategorized" and can be used as the default
#
# Create a new collection folder:
# POST /users/{username}/collection/folders?name={foldername}
#
# Delete a release from a collection folder
# DELETE /users/{username}/collection/folders/{folder_id}/releases/{release_id}/instances/{instance_id}
#
# Set your Discogs username and API token in ~/.config/mpprc as:
# DISCOGS_USER and DISCOGS_TOKEN
# Alternately, they can be provided on the command line or set here.
#
#-----------SET DISCOGS USERNAME-----------------------
DISCOGS_USER=
#
# Discogs API token
# See https://www.discogs.com/settings/developers
# API requests are throttled to 60 per minute for authenticated
# requests and 25 per minute for unauthenticated requests.
#
#-----------SET DISCOGS API TOKEN-----------------------
DISCOGS_TOKEN=
#
# A Discogs username is required.
#
# A Discogs API token is not required. However, API requests for
# unauthenticated users are throttled to 25 per minute and images
# are not available to unauthenticated users.

URL="https://api.discogs.com"
AGE="github.com/doctorfree/MusicPlayerPlus"

# Dot in the user configuration file if it exists
[ -f ${HOME}/.config/mpprc ] && . ${HOME}/.config/mpprc

usage() {
  printf "\nUsage: albums2discogs [-f foldername] [-u username] [-t token] [-v vault] [-hnqry]"
  printf "\nWhere:"
  printf "\n\t-f 'foldername' specifies the Discogs collection folder name to use."
  printf "\n\t\tIf no folder by this name exists, one will be created."
  printf "\n\t\tDefault: Uncategorized"
  printf "\n\t-u 'username' specifies your Discogs username."
  printf "\n\t-t 'token' specifies your Discogs API token."
  printf "\n\t-v 'vault' specifies vault folder name for input markdown."
  printf "\n\t\tThe albums in this vault folder will be added to the Discogs collection."
  printf "\n\t\tIf no vault folder is given then all vault folders will be added."
  printf "\n\t-n indicates perform a dry run, tell me what you would do but do nothing"
  printf "\n\t-q indicates quiet mode, so not display each album added"
  printf "\n\t-r indicates remove mode, remove rather than add releases from a collection"
  printf "\n\t\t-r must be accompanied by '-f foldername'"
  printf "\n\t-y indicates proceed, do not prompt for confirmation to continue"
  printf "\n\t-h displays this usage message and exits.\n"
  printf "\nA Discogs username is required."
  printf "\nA Discogs username and token can be added to ~/.config/mpprc as the variables"
  printf "\n\tDISCOGS_USER and DISCOGS_TOKEN"
  printf "\nor specified on the command line with '-u username' and '-t token'\n"
  exit 1
}

vault=
folderid=1
foldername=
dryrun=
quiet=
proceed=
remove=
# Command line arguments override config file settings
while getopts "f:u:t:v:hnqry" flag; do
    case $flag in
        f)
            foldername="$OPTARG"
            ;;
        u)
            DISCOGS_USER="$OPTARG"
            ;;
        t)
            DISCOGS_TOKEN="$OPTARG"
            ;;
        v)
            vault="$OPTARG"
            ;;
        n)
            dryrun=1
            ;;
        q)
            quiet=1
            ;;
        r)
            remove=1
            ;;
        y)
            proceed=1
            ;;
        h)
            usage
            ;;
    esac
done
shift $(( OPTIND - 1 ))

[ "${remove}" ] && {
  [ "${foldername}" ] || {
    echo "The '-r' (remove) option requires a foldername with '-f foldername'"
    echo "Exiting."
    usage
  }
}

[ "${DISCOGS_USER}" ] || {
  echo "Discogs username required."
  echo "Set DISCOGS_USER in ${HOME}/.config/mpprc or on the command line."
  echo "Exiting."
  usage
}
[ "${DISCOGS_TOKEN}" ] || {
  echo "Discogs API token required."
  echo "Set DISCOGS_TOKEN in ${HOME}/.config/mpprc or on the command line."
  echo "Exiting."
  usage
}

FDR="${URL}/users/${DISCOGS_USER}/collection/folders"
REL="${URL}/users/${DISCOGS_USER}/collection/releases"

# If not a dry run, prompt to confirm
[ "${dryrun}" ] || {
  [ "${proceed}" ] || {
    if [ "${foldername}" ]
    then
      fname="${foldername}"
    else
      fname="Uncategorized"
    fi
    if [ "${remove}" ]
    then
      printf "\nDeleting releases in Discogs user \"${DISCOGS_USER}\" collection folder \"${fname}\"."
    else
      printf "\nAdding releases to Discogs user \"${DISCOGS_USER}\" collection folder \"${fname}\"."
    fi
    printf "\nThis procedure will modify your Discogs account.\n\n"
    while true
    do
      read -p "Do you wish to proceed with the Discogs collection folder update ? (y/n) " yn
      case $yn in
          [Yy]* )
                break
                ;;
          [Nn]* )
                printf "\nDiscogs collection folder update procedure aborted."
                printf "\nExiting.\n\n"
                exit 0
                ;;
              * ) echo "Please answer yes or no."
                ;;
      esac
    done
  }
}

# Check if collection folder exists and if not, create it
if [ "${foldername}" ]
then
  [ "${remove}" ] || {
    folders=$(curl --stderr /dev/null \
      -A "${AGE}" "${FDR}" \
      -H "Authorization: Discogs token=${DISCOGS_TOKEN}" | \
      jq -r '.')
    sleep 1

    folderexists=
    echo "${folders}" | jq -r '.folders[] | (.id|tostring) + ":" + .name' | \
      while IFS=":" read -r id name
      do
        [ "${name}" == "${foldername}" ] && {
          folderexists=1
          folderid="${id}"
          break
        }
      done
  
    [ "${folderexists}" ] || {
      # Create new collection folder
      if [ "${dryrun}" ]
      then
        echo "Would create new collection folder: ${foldername}"
      else
        newfolder=$(curl -X POST --stderr /dev/null \
          -H "Authorization: Discogs token=${DISCOGS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"name\":\"${foldername}\"}" \
          -A "${AGE}" "${FDR}"  | \
          jq -r '.')
        sleep 1
        folderid=`echo "${newfolder}" | jq -r '.id'`
      fi
    }
  }
else
  foldername="Uncategorized"
fi

if [ "${remove}" ]
then
  echo "Deleting albums in Discogs user \"${DISCOGS_USER}\" collection folder \"${foldername}\""
else
  echo "Adding albums to Discogs user \"${DISCOGS_USER}\" collection folder \"${foldername}\""
fi
echo "Please be patient. A large number of albums may take a while."

HERE=`pwd`
[ "${dryrun}" ] || {
  if [ "${remove}" ]
  then
    # Check for JSON return output folder
    [ -d "${HERE}/json/Discogs/${foldername}" ] || {
      printf "\nCollection folder not found."
      printf "\nRequired collection output folder:"
      printf "\n\t${HERE}/json/Discogs/${foldername}"
      printf "\nRemoval only supported for previously generated collection folders."
      printf "\nExiting.\n"
      exit 1
    }
  else
    # Create JSON return output folder
    [ -d "${HERE}/json" ] || mkdir -p "${HERE}/json"
    [ -d "${HERE}/json/Discogs" ] || mkdir -p "${HERE}/json/Discogs"
    [ -d "${HERE}/json/Discogs/${foldername}" ] || {
      mkdir -p "${HERE}/json/Discogs/${foldername}"
    }
  fi
}

add_releases() {
  for album in */*.md
  do
    [ "${album}" == "*/*.md" ] && continue
    release_id=`grep "releaseid:" "${album}" | \
      awk -F ':' ' { print $2 } ' | sed -e 's/^ *//' -e 's/ *$//'`

    # Check if this release is already in the user's collection
    [ "${release_id}" ] || continue
    [ ${release_id} -gt 0 ] || continue
    items=$(curl --stderr /dev/null \
      -H "Authorization: Discogs token=${DISCOGS_TOKEN}" \
      -A "${AGE}" "${REL}/${release_id}" | \
      jq -r '.pagination.items')
    sleep 1
    [ ${items} -gt 0 ] && continue

    # Add this release to the user's collection
    artist=`grep "artist:" "${album}" | \
      awk -F ':' ' { print $2 } ' | sed -e 's/^ *//' -e 's/ *$//'`
    title=`grep "title:" "${album}" | \
      awk -F ':' ' { print $2 } ' | sed -e 's/^ *//' -e 's/ *$//'`
    [ "${title}" ] || {
      title=`grep "album:" "${album}" | \
        awk -F ':' ' { print $2 } ' | sed -e 's/^ *//' -e 's/ *$//'`
    }
    [ "${quiet}" ] || {
      if [ "${dryrun}" ]
      then
        printf "\nWould add album \"${title}\" by ${artist}"
      else
        printf "\nAdding album \"${title}\" by ${artist}"
      fi
      printf "\n\tto Discogs collection folder ${foldername}"
    }
    [ "${dryrun}" ] || {
      newalbum=$(curl -X POST --stderr /dev/null \
        -H "Authorization: Discogs token=${DISCOGS_TOKEN}" \
        -A "${AGE}" "${FDR}/${folderid}/releases/${release_id}" | \
        jq -r '.')
      sleep 1
      albumid=`echo "${newalbum}" | jq -r '.id'`
      echo "${newalbum}" > "${HERE}/json/Discogs/${foldername}/${albumid}.json"
    }
  done
}

if [ "${remove}" ]
then
  for jsonrel in "${HERE}/json/Discogs/${foldername}"/*.json
  do
    [ "${jsonrel}" == "${HERE}/json/Discogs/${foldername}/*.json" ] && continue
    release_id=$(cat "${jsonrel}" | jq -r '.id')
    folder_id=$(cat "${jsonrel}" | jq -r '.folder_id')
    instance_id=$(cat "${jsonrel}" | jq -r '.instance_id')
    [ "${release_id}" ] && [ "${folder_id}" ] && [ "${instance_id}" ] && {
      [ "${quiet}" ] || {
        title=$(cat "${jsonrel}" | jq -r '.basic_information.title')
        if [ "${dryrun}" ]
        then
          printf "\nWould delete album \"${title}\""
        else
          printf "\nDeleting album \"${title}\""
        fi
        printf "\n\tin Discogs collection folder ${foldername}"
      }
      [ "${dryrun}" ] || {
        delalbum=$(curl -X DELETE --stderr /dev/null \
          -H "Authorization: Discogs token=${DISCOGS_TOKEN}" \
          -A "${AGE}" \
          "${FDR}/${folder_id}/releases/${release_id}/instances/${instance_id}" | \
          jq -r '.')
        sleep 1
        rm -f "${jsonrel}"
      }
    }
  done
else
  cd ../..

  if [ "${vault}" ]
  then
    [ -d "${vault}" ] || {
      echo "Cannot locate vault folder ${vault}"
      echo "Exiting without adding any releases to the Discogs collection."
      usage
    }
    cd "${vault}"
    add_releases
    cd ..
  else
    for vault in *
    do
      [ "${vault}" == "assets" ] && continue
      [ "${vault}" == "Dataviews" ] && continue
      [ "${vault}" == "Tools" ] && continue
      [ -d "${vault}" ] && {
        cd "${vault}"
        add_releases
        cd ..
      }
    done
  fi
fi
```
