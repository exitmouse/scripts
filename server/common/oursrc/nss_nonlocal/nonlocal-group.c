/*
 * nonlocal-group.c
 * group database for nss_nonlocal proxy
 *
 * Copyright © 2007 Anders Kaseorg <andersk@mit.edu> and Tim Abbott
 * <tabbott@mit.edu>
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#define _GNU_SOURCE
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <dlfcn.h>
#include <stdio.h>
#include <syslog.h>
#include <errno.h>
#include <grp.h>
#include <nss.h>
#include "nsswitch-internal.h"
#include "nonlocal.h"

#define MAGIC_LOCAL_GR_BUFLEN (sysconf(_SC_GETGR_R_SIZE_MAX) + 7)
#define MAGIC_NONLOCAL_GROUPNAME "nss-nonlocal-users"
#define MAGIC_LOCAL_GROUPNAME "nss-local-users"


static service_user *
nss_group_nonlocal_database(void)
{
    static service_user *nip = NULL;
    if (nip == NULL)
	__nss_database_lookup("group_nonlocal", NULL, "", &nip);

    return nip;
}


enum nss_status
check_nonlocal_gid(const char *user, gid_t gid, int *errnop)
{
    enum nss_status status = NSS_STATUS_SUCCESS;
    struct group gbuf;
    struct group *gbufp = &gbuf;
    int ret;
    int old_errno = errno;
    int buflen = MAGIC_LOCAL_GR_BUFLEN;
    char *buf = malloc(buflen);
    if (buf == NULL) {
	*errnop = ENOMEM;
	errno = old_errno;
	return NSS_STATUS_TRYAGAIN;
    }
    errno = 0;
    ret = getgrgid_r(gid, gbufp, buf, buflen, &gbufp);
    if (ret != 0) {
	*errnop = old_errno;
	status = NSS_STATUS_TRYAGAIN;
    } else if (gbufp != NULL) {
	syslog(LOG_WARNING, "nss_nonlocal: removing local group %u (%s) from non-local user %s\n", gbuf.gr_gid, gbuf.gr_name, user);
	status = NSS_STATUS_NOTFOUND;
    }
    free(buf);
    errno = old_errno;
    return status;
}

enum nss_status
get_local_group(const char *name, struct group *grp, char *buffer, size_t buflen, int *errnop)
{
    enum nss_status status = NSS_STATUS_NOTFOUND;
    struct group gbuf;
    struct group *gbufp = &gbuf;
    int ret, n;
    int old_errno = errno;
    int len = MAGIC_LOCAL_GR_BUFLEN;
    char *buf = malloc(len);
    if (buf == NULL) {
	*errnop = ENOMEM;
	errno = old_errno;
	return NSS_STATUS_TRYAGAIN;
    }
    errno = 0;
    ret = getgrnam_r(name, gbufp, buf, len, &gbufp);
    if (ret != 0) {
	*errnop = old_errno;
	status = NSS_STATUS_TRYAGAIN;
    } else if (gbufp != NULL) {
	status = NSS_STATUS_SUCCESS;

	n = snprintf(buffer, buflen, "%s", gbufp->gr_name);
	if (n < 0 || n >= buflen) {
	    *errnop = ERANGE;
	    status = NSS_STATUS_TRYAGAIN;
	    goto get_local_group_done;
	}
	grp->gr_name = buffer;
	buffer += n;
	buflen -= n;

	n = snprintf(buffer, buflen, "%s", gbufp->gr_passwd);
	if (n < 0 || n >= buflen) {
	    *errnop = ERANGE;
	    status = NSS_STATUS_TRYAGAIN;
	    goto get_local_group_done;
	}
	grp->gr_passwd = buffer;
	buffer += n;
	buflen -= n;

	grp->gr_gid = gbufp->gr_gid;

	if (buflen < sizeof(void *)) {
	    *errnop = ERANGE;
	    status = NSS_STATUS_TRYAGAIN;
	    goto get_local_group_done;
	}
	*(void **)buffer = NULL;
	buffer += sizeof(void *);
	buflen -= sizeof(void *);
    }
 get_local_group_done:
    free(buf);
    errno = old_errno;
    return status;
}

static service_user *grent_nip = NULL;
static void *grent_fct_start;
static union {
    enum nss_status (*l)(struct group *grp, char *buffer, size_t buflen,
			 int *errnop);
    void *ptr;
} grent_fct;
static const char *grent_fct_name = "getgrent_r";

enum nss_status
_nss_nonlocal_setgrent(int stayopen)
{
    static const char *fct_name = "setgrent";
    static void *fct_start = NULL;
    enum nss_status status;
    service_user *nip;
    union {
	enum nss_status (*l)(int stayopen);
	void *ptr;
    } fct;

    nip = nss_group_nonlocal_database();
    if (nip == NULL)
	return NSS_STATUS_UNAVAIL;
    if (fct_start == NULL)
	fct_start = __nss_lookup_function(nip, fct_name);
    fct.ptr = fct_start;
    do {
	if (fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else
	    status = DL_CALL_FCT(fct.l, (stayopen));
    } while (__nss_next(&nip, fct_name, &fct.ptr, status, 0) == 0);
    if (status != NSS_STATUS_SUCCESS)
	return status;

    grent_nip = nip;
    if (grent_fct_start == NULL)
	grent_fct_start = __nss_lookup_function(nip, grent_fct_name);
    grent_fct.ptr = grent_fct_start;
    return NSS_STATUS_SUCCESS;
}

enum nss_status
_nss_nonlocal_endgrent(void)
{
    static const char *fct_name = "endgrent";
    static void *fct_start = NULL;
    enum nss_status status;
    service_user *nip;
    union {
	enum nss_status (*l)(void);
	void *ptr;
    } fct;

    grent_nip = NULL;

    nip = nss_group_nonlocal_database();
    if (nip == NULL)
	return NSS_STATUS_UNAVAIL;
    if (fct_start == NULL)
	fct_start = __nss_lookup_function(nip, fct_name);
    fct.ptr = fct_start;
    do {
	if (fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else
	    status = DL_CALL_FCT(fct.l, ());
    } while (__nss_next(&nip, fct_name, &fct.ptr, status, 0) == 0);
    return status;
}

enum nss_status
_nss_nonlocal_getgrent_r(struct group *grp, char *buffer, size_t buflen,
			 int *errnop)
{
    enum nss_status status;

    char *nonlocal_ignore = getenv(NONLOCAL_IGNORE_ENV);
    if (buflen == MAGIC_LOCAL_GR_BUFLEN ||
	(nonlocal_ignore != NULL && nonlocal_ignore[0] != '\0'))
	return NSS_STATUS_UNAVAIL;

    if (grent_nip == NULL) {
	status = _nss_nonlocal_setgrent(0);
	if (status != NSS_STATUS_SUCCESS)
	    return status;
    }
    do {
	if (grent_fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else {
	    int nonlocal_errno;
	    do
		status = DL_CALL_FCT(grent_fct.l, (grp, buffer, buflen, errnop));
	    while (status == NSS_STATUS_SUCCESS &&
		   check_nonlocal_gid("(unknown)", grp->gr_gid, &nonlocal_errno) != NSS_STATUS_SUCCESS);
	}
	if (status == NSS_STATUS_TRYAGAIN && *errnop == ERANGE)
	    return status;

	if (status == NSS_STATUS_SUCCESS)
	    return NSS_STATUS_SUCCESS;
    } while (__nss_next(&grent_nip, grent_fct_name, &grent_fct.ptr, status, 0) == 0);

    grent_nip = NULL;
    return NSS_STATUS_NOTFOUND;
}


enum nss_status
_nss_nonlocal_getgrnam_r(const char *name, struct group *grp,
			 char *buffer, size_t buflen, int *errnop)
{
    static const char *fct_name = "getgrnam_r";
    static void *fct_start = NULL;
    enum nss_status status;
    service_user *nip;
    union {
	enum nss_status (*l)(const char *name, struct group *grp,
			     char *buffer, size_t buflen, int *errnop);
	void *ptr;
    } fct;

    char *nonlocal_ignore = getenv(NONLOCAL_IGNORE_ENV);
    if (buflen == MAGIC_LOCAL_GR_BUFLEN ||
	(nonlocal_ignore != NULL && nonlocal_ignore[0] != '\0'))
	return NSS_STATUS_UNAVAIL;

    nip = nss_group_nonlocal_database();
    if (nip == NULL)
	return NSS_STATUS_UNAVAIL;
    if (fct_start == NULL)
	fct_start = __nss_lookup_function(nip, fct_name);
    fct.ptr = fct_start;
    do {
	if (fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else
	    status = DL_CALL_FCT(fct.l, (name, grp, buffer, buflen, errnop));
	if (status == NSS_STATUS_TRYAGAIN && *errnop == ERANGE)
	    break;
    } while (__nss_next(&nip, fct_name, &fct.ptr, status, 0) == 0);
    if (status != NSS_STATUS_SUCCESS)
	return status;

    return check_nonlocal_gid(name, grp->gr_gid, errnop);
}

enum nss_status
_nss_nonlocal_getgrgid_r(gid_t gid, struct group *grp,
			 char *buffer, size_t buflen, int *errnop)
{
    static const char *fct_name = "getgrgid_r";
    static void *fct_start = NULL;
    enum nss_status status;
    service_user *nip;
    union {
	enum nss_status (*l)(gid_t gid, struct group *grp,
			     char *buffer, size_t buflen, int *errnop);
	void *ptr;
    } fct;

    char *nonlocal_ignore = getenv(NONLOCAL_IGNORE_ENV);
    if (buflen == MAGIC_LOCAL_GR_BUFLEN ||
	(nonlocal_ignore != NULL && nonlocal_ignore[0] != '\0'))
	return NSS_STATUS_UNAVAIL;

    nip = nss_group_nonlocal_database();
    if (nip == NULL)
	return NSS_STATUS_UNAVAIL;
    if (fct_start == NULL)
	fct_start = __nss_lookup_function(nip, fct_name);
    fct.ptr = fct_start;
    do {
	if (fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else
	    status = DL_CALL_FCT(fct.l, (gid, grp, buffer, buflen, errnop));
	if (status == NSS_STATUS_TRYAGAIN && *errnop == ERANGE)
	    break;
    } while (__nss_next(&nip, fct_name, &fct.ptr, status, 0) == 0);
    if (status != NSS_STATUS_SUCCESS)
	return status;

    return check_nonlocal_gid(grp->gr_name, grp->gr_gid, errnop);
}

enum nss_status
_nss_nonlocal_initgroups_dyn(const char *user, gid_t group, long int *start,
			     long int *size, gid_t **groupsp, long int limit,
			     int *errnop)
{
    static const char *fct_name = "initgroups_dyn";
    static void *fct_start = NULL;
    enum nss_status status;
    service_user *nip;
    union {
	enum nss_status (*l)(const char *user, gid_t group, long int *start,
			     long int *size, gid_t **groupsp, long int limit,
			     int *errnop);
	void *ptr;
    } fct;

    struct group local_users_group, nonlocal_users_group;
    gid_t local_users_gid, gid;
    int is_local = 0;
    int buflen;
    char *buffer;

    /* Check that the user is a nonlocal user before adding any groups. */
    status = check_nonlocal_user(user, errnop);
    if (status == NSS_STATUS_NOTFOUND)
	is_local = 1;
    else if (status != NSS_STATUS_SUCCESS)
	return status;

    int old_errno = errno;

    buflen = sysconf(_SC_GETGR_R_SIZE_MAX);
    buffer = malloc(buflen);
    if (buffer == NULL) {
	*errnop = ENOMEM;
	errno = old_errno;
	return NSS_STATUS_TRYAGAIN;
    }
    status = get_local_group(MAGIC_LOCAL_GROUPNAME,
			     &local_users_group, buffer, buflen, errnop);
    if (status == NSS_STATUS_NOTFOUND) {
	syslog(LOG_WARNING, "nss_nonlocal: Group %s does not exist locally!",
	       MAGIC_LOCAL_GROUPNAME);
	local_users_gid = -1;
    } else if (status != NSS_STATUS_SUCCESS) {
	return status;
    } else
	local_users_gid = local_users_group.gr_gid;
    free(buffer);

    if (is_local) {
	gid = local_users_gid;
    } else {
	buflen = sysconf(_SC_GETGR_R_SIZE_MAX);
	buffer = malloc(buflen);
	if (buffer == NULL) {
	    *errnop = ENOMEM;
	    errno = old_errno;
	    return NSS_STATUS_TRYAGAIN;
	}
 	status = get_local_group(MAGIC_NONLOCAL_GROUPNAME,
				 &nonlocal_users_group, buffer, buflen, errnop);
	if (status == NSS_STATUS_NOTFOUND) {
	    syslog(LOG_WARNING, "nss_nonlocal: Group %s does not exist locally!",
		   MAGIC_NONLOCAL_GROUPNAME);
	    gid = -1;
	} else if (status != NSS_STATUS_SUCCESS) {
	    errno = old_errno;
	    return status;
	} else
	    gid = nonlocal_users_group.gr_gid;
	free(buffer);
    }

    if (gid != -1) {
	int i;
	for (i = 0; i < *start; ++i)
	    if ((*groupsp)[i] == gid)
		break;
	if (i >= *start) {
	    if (*start + 1 > *size) {
		gid_t *newgroups;
		long int newsize = 2 * *size;
		if (limit > 0) {
		    if (*size >= limit)
			return NSS_STATUS_SUCCESS;
		    if (newsize > limit)
			newsize = limit;
		}
		newgroups = realloc(*groupsp, *size * sizeof((*groupsp)[0]));
		if (newgroups == NULL) {
		    *errnop = ENOMEM;
		    errno = old_errno;
		    return NSS_STATUS_TRYAGAIN;
		}
		*groupsp = newgroups;
		*size = newsize;
	    }
	    (*groupsp)[(*start)++] = gid;
	}
    }

    errno = old_errno;

    if (is_local)
	return NSS_STATUS_SUCCESS;

    int in = *start, out = *start, i;

    nip = nss_group_nonlocal_database();
    if (nip == NULL)
	return NSS_STATUS_UNAVAIL;
    if (fct_start == NULL)
	fct_start = __nss_lookup_function(nip, fct_name);
    fct.ptr = fct_start;

    do {
	if (fct.ptr == NULL)
	    status = NSS_STATUS_UNAVAIL;
	else
	    status = DL_CALL_FCT(fct.l, (user, group, start, size, groupsp, limit, errnop));
        if (status == NSS_STATUS_TRYAGAIN && *errnop == ERANGE)
            break;
    } while (__nss_next(&nip, fct_name, &fct.ptr, status, 0) == 0);
    if (status != NSS_STATUS_SUCCESS)
        return status;

    for (; in < *start; ++in) {
	int nonlocal_errno = *errnop;

	for (i = 0; i < out; ++i)
	    if ((*groupsp)[i] == (*groupsp)[in])
		break;
	if (i < out)
	    continue;

	/* Don't let users get into MAGIC_LOCAL_GROUPNAME from nonlocal reasons. */
	if (local_users_gid == (*groupsp)[in]) {
	    syslog(LOG_WARNING, "nss_nonlocal: Nonlocal user %s removed from special local users group %s",
		   user, MAGIC_LOCAL_GROUPNAME);
	    continue;
	}

	status = check_nonlocal_gid(user, (*groupsp)[in], &nonlocal_errno);
	if (status == NSS_STATUS_SUCCESS) {
	    (*groupsp)[out++] = (*groupsp)[in];
	} else if (status != NSS_STATUS_NOTFOUND) {
	    *start = out;
	    *errnop = nonlocal_errno;
	    return status;
	}
    }

    *start = out;
    return NSS_STATUS_SUCCESS;
}