#!/usr/bin/env bash
set -euo pipefail

SMACK_VERSION="4.4.6"
CURL_ARGS="--location --silent"
DEBUG=false

HOST='example.org'
ADMINUSER='admin'
ADMINPASS='admin'

usage()
{
	echo "Usage: $0 [-d] [-l] [-s SMACK_VERSION] [-h HOST] [-u USERNAME] [-p PASSWORD]"
	echo "    -d: Enable debug mode. Prints commands, and preserves temp directories if used (default: off)"
	echo "    -s: Set Smack to the given version (default: ${SMACK_VERSION})"
	echo "    -l: Launch a local Openfire. (default: off)"
	echo "    -h: The hostname for the Openfire under test (default: example.org)"
	echo "    -u: Admin username for Openfire (default: admin)"
	echo "    -p: Admin password for Openfire (default: admin)"
	exit 2
}

while getopts dls:h:u:p: OPTION "$@"; do
	case $OPTION in
		d)
			DEBUG=true
			set -x
			;;
		l)
			LOCAL_RUN=true
			;;
		s)
			SMACK_VERSION="${OPTARG}"
			;;
		h)
			HOST="${OPTARG}"
			;;
		u)
			ADMINUSER="${OPTARG}"
			;;
		p)
			ADMINPASS="${OPTARG}"
			;;
		\? ) usage;;
        :  ) usage;;
        *  ) usage;;
	esac
done

if [[ $LOCAL_RUN == true ]] && [[ $HOST != "example.org" ]]; then
	echo "Host is fixed if launching a local instance. If you have an already-running instance to test against, omit the -l flag (and provide -i 127.0.0.1 if necessary)."
	exit 1
fi

echo "Starting Integration Tests (using Smack ${SMACK_VERSION})…"

DISABLED_INTEGRATION_TESTS=()

# Occasionally fail because of unstable AbstractSmackIntegrationTest#performActionAndWaitForPresence being used.
# See https://github.com/igniterealtime/Smack/commit/5bfe789e08ebb251b3c4302cb653c715eee363ea for unstable solution.
# Disable until AbstractSmackIntegrationTest#performActionAndWaitForPresence is improved/replaced.
DISABLED_INTEGRATION_TESTS+=(EntityCapsTest)
DISABLED_INTEGRATION_TESTS+=(SoftwareInfoIntegrationTest)

# Occasionally fails, disabled until cause can be found.
DISABLED_INTEGRATION_TESTS+=(XmppConnectionIntegrationTest)
DISABLED_INTEGRATION_TESTS+=(StreamManagementTest)
DISABLED_INTEGRATION_TESTS+=(WaitForClosingStreamElementTest)
DISABLED_INTEGRATION_TESTS+=(IoTControlIntegrationTest)
DISABLED_INTEGRATION_TESTS+=(ModularXmppClientToServerConnectionLowLevelIntegrationTest)

SINTTEST_DISABLED_TESTS_ARGUMENT="-Dsinttest.disabledTests="
for disabledTest in "${DISABLED_INTEGRATION_TESTS[@]}"; do
	SINTTEST_DISABLED_TESTS_ARGUMENT+="${disabledTest},"
done
# Remove last ',' from the argument. Can't use ${SINTTEST_DISABLED_TESTS_ARGUMENT::-1} because bash on MacOS is infuriatingly incompatible.
SINTTEST_DISABLED_TESTS_ARGUMENT="${SINTTEST_DISABLED_TESTS_ARGUMENT:0:$((${#SINTTEST_DISABLED_TESTS_ARGUMENT}-1))}"

./gradlew --console=plain \
		--build-file test.gradle \
		-PsmackVersion="${SMACK_VERSION}" \
		-q dependencies
./gradlew --console=plain \
		--stacktrace \
		run \
		-b test.gradle \
		-PsmackVersion="${SMACK_VERSION}" \
		-Dsinttest.service="${HOST}" \
		-Dsinttest.securityMode=disabled \
		-Dsinttest.replyTimeout=60000 \
		-Dsinttest.adminAccountUsername="${ADMINUSER}" \
		-Dsinttest.adminAccountPassword="${ADMINPASS}" \
		-Dsinttest.enabledConnections=tcp \
		-Dsinttest.dnsResolver=javax \
		${SINTTEST_DISABLED_TESTS_ARGUMENT}
