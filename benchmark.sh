#!/bin/bash -ex

BASEDIR=`pwd`

# Clone doctored JUnit 5 repo
if [ ! -d spring-framework ]
then
	rm -rf spring-framework
	git clone git@github.com:lptr/spring-framework.git
fi

cd spring-framework

GRADLE_HOME="$BASEDIR/gradle-home"
COMMON_OPTIONS="--init-script=$BASEDIR/build-scan.gradle"
TIME_LOG="$BASEDIR/results.txt"
BUILD_LOG="$BASEDIR/benchmark.log"
TASKS="check"
# TASKS=":spring-jdbc:check"
# TASKS=help
COUNT=5

rm -f "$TIME_LOG" "$BUILD_LOG"

function cleanup {
	rm -rf "$GRADLE_HOME/caches/build-cache-1"
	git reset --hard
	git clean -fdx
}

function gradle {
	./gradlew -g "$GRADLE_HOME" $OPTIONS $@
}

function measureGradle {
	echo "Executing ./gradlew -g \"$GRADLE_HOME\" $OPTIONS $@" >> "$BUILD_LOG"
	(/usr/bin/time ./gradlew -g "$GRADLE_HOME" $OPTIONS $@) 2>> "$TIME_LOG" | tee --append "$BUILD_LOG" | tail -n 10 | grep "^https://" >> "$TIME_LOG"
	echo "" >> "$TIME_LOG"
	echo "" >> "$BUILD_LOG"
}

gradle --version

#
# With local cache
#

OPTIONS="$COMMON_OPTIONS --build-cache"
gradle --stop

for i in `seq $COUNT`
do
	echo "Execution #$i - with cache" >> "$TIME_LOG"

	# Remove any previous results
	cleanup

	# Simulate CI pushing remote changes to cache
	patch -p1 < "$BASEDIR/remote.patch"
	gradle clean $TASKS

	# Restore local working copy to before remote change
	patch -p1 -R < "$BASEDIR/remote.patch"
	gradle clean $TASKS

	# Simulate pulling remote changes
	patch -p1 < "$BASEDIR/remote.patch"
	# Make local changes on top
	patch -p1 < "$BASEDIR/local.patch"

	# Build both remote and local changes
	measureGradle $TASKS
done

#
# Without cache
#

OPTIONS="$COMMON_OPTIONS"
gradle --stop

for i in `seq $COUNT`
do
	echo "Execution #$i - no cache" >> "$TIME_LOG"

	# Remove any previous results
	cleanup

	# Establish baseline
	gradle clean $TASKS

	# Simulate pulling remote changes
	patch -p1 < "$BASEDIR/remote.patch"
	# Make local changes on top
	patch -p1 < "$BASEDIR/local.patch"

	# Build both remote and local changes
	measureGradle $TASKS
done

cleanup

cd "$BASEDIR"
