#!/bin/sh
# Run this to generate all the initial makefiles, etc.
# Ripped off from GNOME macros version

DIE=0

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

if [ -n "$MONO_PATH" ]; then
	# from -> /mono/lib:/another/mono/lib
	# to -> /mono /another/mono
	for i in `echo ${MONO_PATH} | tr ":" " "`; do
		i=`dirname ${i}`
		if [ -n "{i}" -a -d "${i}/share/aclocal" ]; then
			ACLOCAL_FLAGS="-I ${i}/share/aclocal $ACLOCAL_FLAGS"
		fi
		if [ -n "{i}" -a -d "${i}/bin" ]; then
			PATH="${i}/bin:$PATH"
		fi
	done
	export PATH
fi

(autoconf --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "**Error**: You must have \`autoconf' installed to compile Mono."
  echo "Download the appropriate package for your distribution,"
  echo "or get the source tarball at ftp://ftp.gnu.org/pub/gnu/"
  DIE=1
}

if [ -z "$LIBTOOL" ]; then
  LIBTOOL=`which glibtool 2>/dev/null` 
  if [ ! -x "$LIBTOOL" ]; then
    LIBTOOL=`which libtool`
  fi
fi

(grep "^AM_PROG_LIBTOOL" $srcdir/configure.in >/dev/null) && {
  ($LIBTOOL --version) < /dev/null > /dev/null 2>&1 || {
    echo
    echo "**Error**: You must have \`libtool' installed to compile Mono."
    echo "Get ftp://ftp.gnu.org/pub/gnu/libtool-1.2d.tar.gz"
    echo "(or a newer version if it is available)"
    DIE=1
  }
}

grep "^AM_GNU_GETTEXT" $srcdir/configure.in >/dev/null && {
  grep "sed.*POTFILES" $srcdir/configure.in >/dev/null || \
  (gettext --version) < /dev/null > /dev/null 2>&1 || {
    echo
    echo "**Error**: You must have \`gettext' installed to compile Mono."
    echo "Get ftp://alpha.gnu.org/gnu/gettext-0.10.35.tar.gz"
    echo "(or a newer version if it is available)"
    DIE=1
  }
}

(automake --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "**Error**: You must have \`automake' installed to compile Mono."
  echo "Get ftp://ftp.gnu.org/pub/gnu/automake-1.3.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
  NO_AUTOMAKE=yes
}


# if no automake, don't bother testing for aclocal
test -n "$NO_AUTOMAKE" || (aclocal --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "**Error**: Missing \`aclocal'.  The version of \`automake'"
  echo "installed doesn't appear recent enough."
  echo "Get ftp://ftp.gnu.org/pub/gnu/automake-1.3.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
}

if test "$DIE" -eq 1; then
  exit 1
fi

if test -z "$*"; then
  echo "**Warning**: I am going to run \`configure' with no arguments."
  echo "If you wish to pass any to it, please specify them on the"
  echo \`$0\'" command line."
  echo
fi

case $CC in
xlc )
  am_opt=--include-deps;;
esac


if grep "^AM_PROG_LIBTOOL" configure.in >/dev/null; then
  if test -z "$NO_LIBTOOLIZE" ; then 
    echo "Running libtoolize..."
    ${LIBTOOL}ize --force --copy
    #${LIBTOOL}ize --copy
  fi
fi

echo "Running aclocal $ACLOCAL_FLAGS ..."
aclocal $ACLOCAL_FLAGS || {
  echo
  echo "**Error**: aclocal failed. This may mean that you have not"
  echo "installed all of the packages you need, or you may need to"
  echo "set ACLOCAL_FLAGS to include \"-I \$prefix/share/aclocal\""
  echo "for the prefix where you installed the packages whose"
  echo "macros were not found"
  exit 1
}

if grep "^AC_CONFIG_HEADERS" configure.in >/dev/null; then
  echo "Running autoheader..."
  autoheader || { echo "**Error**: autoheader failed."; exit 1; }
fi

echo "Running automake --gnu $am_opt ..."
automake --add-missing --gnu $am_opt ||
  { echo "**Error**: automake failed."; exit 1; }
echo "Running autoconf ..."
autoconf || { echo "**Error**: autoconf failed."; exit 1; }

CONF_OPTIONS=""
CAIRO_AUTOGEN_REQUIRED=1
until [ -z "$1" ]
do
  if [ "$1" = "--skip-cairo" ]; then
    echo Skipping internal pixman and cairo ...
    CAIRO_AUTOGEN_REQUIRED=0
  fi
  CONF_OPTIONS="$CONF_OPTIONS $1"
  shift
done

if test "$CAIRO_AUTOGEN_REQUIRED" -eq 1; then
  if test -d $srcdir/pixman; then
    echo Running pixman/autogen.sh ...
    (cd $srcdir/pixman ; NOCONFIGURE=1 ./autogen.sh "$@")
    echo Done running autogen.sh in pixman...
  fi
  if test -d $srcdir/cairo; then
    echo Running cairo/autogen.sh ...
     (cd $srcdir/cairo ; NOCONFIGURE=1 ./autogen.sh "$@")
     echo Done running autogen.sh in cairo...
  fi
fi


conf_flags="--enable-maintainer-mode --enable-compile-warnings" #--enable-iso-c

if test x$NOCONFIGURE = x; then
  echo Running $srcdir/configure $conf_flags $CONF_OPTIONS ...
  $srcdir/configure $conf_flags $CONF_OPTIONS \
  && echo Now type \`make\' to compile $PKG_NAME || exit 1
else
  echo Skipping configure process.
fi
