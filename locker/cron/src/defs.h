
/*
 * DEFS.H
 *
 * Copyright 1994-1998 Matthew Dillon (dillon@backplane.com)
 * May be distributed under the GNU General Public License
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <dirent.h>
#include <fcntl.h>
#include <pwd.h>
#include <unistd.h>
#include <grp.h>
#include <err.h>

#define Prototype extern
#define arysize(ary)	(sizeof(ary)/sizeof((ary)[0]))

#ifndef SCRIPTS_CRONTABS
#define SCRIPTS_CRONTABS	"/mit/scripts/cron/crontabs"
#endif
#ifndef TMPDIR
#define TMPDIR		"/tmp"
#endif
#ifndef OPEN_MAX
#define OPEN_MAX	256
#endif

#ifndef CRONUPDATE
#define CRONUPDATE	"cron.update"
#endif

#ifndef MAXLINES
#define MAXLINES	256		/* max lines in non-root crontabs */
#endif
