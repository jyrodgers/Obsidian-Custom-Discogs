#!/bin/bash
#
# Setup.sh
#
# Setup the Custom Discogs vault with markdown from the user Discogs collection

URL="https://api.discogs.com"
AGE="github.com/doctorfree/MusicPlayerPlus"
UPD=

[ -x Tools/Discogs/mkdiscogs ] || {
  echo "Tools/Discogs/mkdiscogs does not exist or is not executable."
  echo "The Setup.sh script must be run in the Obsidian-Custom-Discogs folder."
  echo "Exiting without performing custom setup."
  exit 1
}

# Get the Discogs username and a Discogs API token
[ -f "${HOME}/.config/mpprc" ] && . "${HOME}/.config/mpprc"

usage() {
  printf "\nUsage: ./Setup.sh [-U] [-t token] [-u user] [-h]"
  printf "\nWhere:"
  printf "\n\t-U indicates perform an update of the Discogs collection"
  printf "\n\t-t 'token' specifies the Discogs API token"
  printf "\n\t-u 'user' specifies the Discogs username"
  printf "\n\t-h displays this usage message and exits\n\n"
  exit 1
}

while getopts "Ut:u:h" flag; do
    case $flag in
        U)
            UPD="-U"
            ;;
        t)
            DISCOGS_TOKEN="${OPTARG}"
            ;;
        u)
            DISCOGS_USER="${OPTARG}"
            ;;
        h)
            usage
            ;;
    esac
done
shift $(( OPTIND - 1 ))

[ "${DISCOGS_USER}" ] || {
  printf "\nDiscogs username required but none found in ~/.config/mpprc"
  printf "\nThe Discogs username can be found by visiting discogs.com. Login then"
  printf "\nuse the dropdown of your user icon in the upper right corner. Click on"
  printf "\n'Profile'. Your Discogs username is the last component of the profile URL."
  printf "\nPlease enter your Discogs username.\n"
  numtries=1
  while true
  do
    read -p "Discogs username: " username
    case ${username} in
      [?]* )
          DISCOGS_USER="${username}"
          curl --stderr /dev/null \
               -A "${AGE}" "${URL}/users/${username}" | \
               grep "User does not exist" > /dev/null && {
                   DISCOGS_USER=
               }
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

[ "${DISCOGS_TOKEN}" ] || {
  printf "\nDiscogs API token not found in ~/.config/mpprc"
  printf "\nLogin to discogs.com and visit:\n"
  printf "\n\thttps://www.discogs.com/settings/developers\n"
  printf "\nto find or generate a Discogs API token.\n"
  printf "\nPlease enter a Discogs API token.\n"
  numtries=1
  while true
  do
    read -p "Discogs API token: " token
    case ${token} in
      [?]* )
          DISCOGS_TOKEN="${token}"
          curl --stderr /dev/null \
               -A "${AGE}" \
               -H "Authorization: Discogs token=${token}" \
               "${URL}/users/${username}" | \
               grep "Invalid consumer token" > /dev/null && {
                   DISCOGS_TOKEN=
               }
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

cd Tools/Discogs
./mkdiscogs -a -t "${DISCOGS_TOKEN}" -u "${DISCOGS_USER}" ${UPD}
