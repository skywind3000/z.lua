//=====================================================================
//
// iposix.c - posix file system accessing
//
// NOTE:
// for more information, please see the readme file.
//
//=====================================================================

#include "iposix.h"

#ifndef IDISABLE_FILE_SYSTEM_ACCESS
//---------------------------------------------------------------------
// Global Definition
//---------------------------------------------------------------------
#include <sys/types.h>
#include <sys/stat.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>

#if defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
#include <sys/sysctl.h>
#endif

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <windows.h>
#define ISYSNAME 'w'
#else
#ifndef __unix
#define __unix
#endif
#define ISYSNAME 'u'
#endif



//---------------------------------------------------------------------
// Posix Stat
//---------------------------------------------------------------------
#ifdef __unix
typedef struct stat iposix_ostat_t;
#define iposix_stat_proc	stat
#define iposix_lstat_proc	lstat
#define iposix_fstat_proc	fstat
#else
typedef struct _stat iposix_ostat_t;
#define iposix_stat_proc	_stat
#define iposix_lstat_proc	_stat
#define iposix_fstat_proc	_fstat
#endif


#if defined(_WIN32) || defined(WIN32) || defined(_WIN64) || defined(WIN64)
	#if defined(_S_IFMT) && (!defined(S_IFMT))
		#define S_IFMT _S_IFMT
	#endif

	#if defined(_S_IFDIR) && (!defined(S_IFDIR))
		#define S_IFDIR _S_IFDIR
	#endif

	#if defined(_S_IFCHR) && (!defined(S_IFCHR))
		#define S_IFCHR _S_IFCHR
	#endif

	#if defined(_S_IFIFO) && (!defined(S_IFIFO))
		#define S_IFIFO _S_IFIFO
	#endif

	#if defined(_S_IFREG) && (!defined(S_IFREG))
		#define S_IFREG _S_IFREG
	#endif

	#if defined(_S_IREAD) && (!defined(S_IREAD))
		#define S_IREAD _S_IREAD
	#endif

	#if defined(_S_IWRITE) && (!defined(S_IWRITE))
		#define S_IWRITE _S_IWRITE
	#endif

	#if defined(_S_IEXEC) && (!defined(S_IEXEC))
		#define S_IEXEC _S_IEXEC
	#endif
#endif

#define IX_FMT(m, t)  (((m) & S_IFMT) == (t))


// convert stat structure
void iposix_stat_convert(iposix_stat_t *ostat, const iposix_ostat_t *x)
{
	ostat->st_mode = 0;

	#ifdef S_IFDIR
	if (IX_FMT(x->st_mode, S_IFDIR)) ostat->st_mode |= ISTAT_IFDIR;
	#endif
	#ifdef S_IFCHR
	if (IX_FMT(x->st_mode, S_IFCHR)) ostat->st_mode |= ISTAT_IFCHR;
	#endif
	#ifdef S_IFBLK
	if (IX_FMT(x->st_mode, S_IFBLK)) ostat->st_mode |= ISTAT_IFBLK;
	#endif
	#ifdef S_IFREG
	if (IX_FMT(x->st_mode, S_IFREG)) ostat->st_mode |= ISTAT_IFREG;
	#endif
	#ifdef S_IFIFO
	if (IX_FMT(x->st_mode, S_IFIFO)) ostat->st_mode |= ISTAT_IFIFO;
	#endif
	#ifdef S_IFLNK
	if (IX_FMT(x->st_mode, S_IFLNK)) ostat->st_mode |= ISTAT_IFLNK;
	#endif
	#ifdef S_IFSOCK
	if (IX_FMT(x->st_mode, S_IFSOCK)) ostat->st_mode |= ISTAT_IFSOCK;
	#endif
	#ifdef S_IFWHT
	if (IX_FMT(x->st_mode, S_IFWHT)) ostat->st_mode |= ISTAT_IFWHT;
	#endif

#ifdef S_IREAD
	if (x->st_mode & S_IREAD) ostat->st_mode |= ISTAT_IRUSR;
#endif

#ifdef S_IWRITE
	if (x->st_mode & S_IWRITE) ostat->st_mode |= ISTAT_IWUSR;
#endif

#ifdef S_IEXEC
	if (x->st_mode & S_IEXEC) ostat->st_mode |= ISTAT_IXUSR;
#endif

#ifdef S_IRUSR
	if (x->st_mode & S_IRUSR) ostat->st_mode |= ISTAT_IRUSR;
	if (x->st_mode & S_IWUSR) ostat->st_mode |= ISTAT_IWUSR;
	if (x->st_mode & S_IXUSR) ostat->st_mode |= ISTAT_IXUSR;
#endif

#ifdef S_IRGRP
	if (x->st_mode & S_IRGRP) ostat->st_mode |= ISTAT_IRGRP;
	if (x->st_mode & S_IWGRP) ostat->st_mode |= ISTAT_IWGRP;
	if (x->st_mode & S_IXGRP) ostat->st_mode |= ISTAT_IXGRP;
#endif

#ifdef S_IROTH
	if (x->st_mode & S_IROTH) ostat->st_mode |= ISTAT_IROTH;
	if (x->st_mode & S_IWOTH) ostat->st_mode |= ISTAT_IWOTH;
	if (x->st_mode & S_IXOTH) ostat->st_mode |= ISTAT_IXOTH;
#endif
	
	ostat->st_size = (IUINT64)x->st_size;

	ostat->atime = (IUINT32)x->st_atime;
	ostat->mtime = (IUINT32)x->st_mtime;
	ostat->ctime = (IUINT32)x->st_mtime;

	ostat->st_ino = (IUINT64)x->st_ino;
	ostat->st_dev = (IUINT32)x->st_dev;
	ostat->st_nlink = (IUINT32)x->st_nlink;
	ostat->st_uid = (IUINT32)x->st_uid;
	ostat->st_gid = (IUINT32)x->st_gid;
	ostat->st_rdev = (IUINT32)x->st_rdev;

#ifdef __unix
//	#define IHAVE_STAT_ST_BLKSIZE
//	#define IHAVE_STAT_ST_BLOCKS
//	#define IHAVE_STAT_ST_FLAGS
#endif

#if defined(__unix)
	#ifdef IHAVE_STAT_ST_BLOCKS
	ostat->st_blocks = (IUINT32)x->st_blocks;
	#endif
	#ifdef IHAVE_STAT_ST_BLKSIZE
	ostat->st_blksize = (IUINT32)x->st_blksize;
	#endif
	#if !defined(__CYGWIN__) && defined(IHAVE_STAT_ST_FLAGS)
	ostat->st_flags = (IUINT32)x->st_flags;
	#endif
#endif
}

// returns 0 for success, -1 for error
int iposix_stat_imp(const char *path, iposix_stat_t *ostat)
{
	iposix_ostat_t xstat;
	int retval;
	retval = iposix_stat_proc(path, &xstat);
	if (retval != 0) return -1;
	iposix_stat_convert(ostat, &xstat);
	return 0;
}

// returns 0 for success, -1 for error
int iposix_lstat_imp(const char *path, iposix_stat_t *ostat)
{
	iposix_ostat_t xstat;
	int retval;
	retval = iposix_lstat_proc(path, &xstat);
	if (retval != 0) return -1;
	iposix_stat_convert(ostat, &xstat);
	return 0;
}

// returns 0 for success, -1 for error
int iposix_fstat(int fd, iposix_stat_t *ostat)
{
	iposix_ostat_t xstat;
	int retval;
	retval = iposix_fstat_proc(fd, &xstat);
	if (retval != 0) return -1;
	iposix_stat_convert(ostat, &xstat);
	return 0;
}

// normalize stat path
static void iposix_path_stat(const char *src, char *dst)
{
	int size = (int)strlen(src);
	if (size > IPOSIX_MAXPATH) size = IPOSIX_MAXPATH;
	memcpy(dst, src, size + 1);
	if (size > 1) {
		int trim = 1;
		if (size == 3) {
			if (isalpha((int)dst[0]) && dst[1] == ':' && 
				(dst[2] == '/' || dst[2] == '\\')) trim = 0;
		}
		if (size == 1) {
			if (dst[0] == '/' || dst[0] == '\\') trim = 0;
		}
		if (trim) {
			if (dst[size - 1] == '/' || dst[size - 1] == '\\') {
				dst[size - 1] = 0;
				size--;
			}
		}
	}
}


// returns 0 for success, -1 for error
int iposix_stat(const char *path, iposix_stat_t *ostat)
{
	char buf[IPOSIX_MAXBUFF];
	iposix_path_stat(path, buf);
	return iposix_stat_imp(buf, ostat);
}

// returns 0 for success, -1 for error
int iposix_lstat(const char *path, iposix_stat_t *ostat)
{
	char buf[IPOSIX_MAXBUFF];
	iposix_path_stat(path, buf);
	return iposix_lstat_imp(buf, ostat);
}

// get current directory
char *iposix_getcwd(char *path, int size)
{
#ifdef _WIN32
	return _getcwd(path, size);
#else
	return getcwd(path, size);
#endif
}

// create directory
int iposix_mkdir(const char *path, int mode)
{
#ifdef _WIN32
	return _mkdir(path);
#else
	if (mode < 0) mode = 0755;
	return mkdir(path, mode);
#endif
}

// change directory
int iposix_chdir(const char *path)
{
#ifdef _WIN32
	return _chdir(path);
#else
	return chdir(path);
#endif
}

// check access
int iposix_access(const char *path, int mode)
{
#ifdef _WIN32
	return _access(path, mode);
#else
	return access(path, mode);
#endif
}

// returns 1 for true 0 for false, -1 for not exist
int iposix_path_isdir(const char *path)
{
	iposix_stat_t s;
	int hr = iposix_stat(path, &s);
	if (hr != 0) return -1;
	return (ISTAT_ISDIR(s.st_mode))? 1 : 0;
}

// returns 1 for true 0 for false, -1 for not exist
int iposix_path_isfile(const char *path)
{
	iposix_stat_t s;
	int hr = iposix_stat(path, &s);
	if (hr != 0) return -1;
	return (ISTAT_ISDIR(s.st_mode))? 0 : 1;
}

// returns 1 for true 0 for false, -1 for not exist
int iposix_path_islink(const char *path)
{
	iposix_stat_t s;
	int hr = iposix_stat(path, &s);
	if (hr != 0) return -1;
	return (ISTAT_ISLNK(s.st_mode))? 1 : 0;
}

// returns 1 for true 0 for false
int iposix_path_exists(const char *path)
{
	iposix_stat_t s;
	int hr = iposix_stat(path, &s);
	if (hr != 0) return 0;
	return 1;
}

// returns file size, -1 for error
IINT64 iposix_path_getsize(const char *path)
{
	iposix_stat_t s;
	int hr = iposix_stat(path, &s);
	if (hr != 0) return -1;
	return (IINT64)s.st_size;
}


//---------------------------------------------------------------------
// Posix Path
//---------------------------------------------------------------------

// 是否是绝对路径，如果是的话返回1，否则返回0
int iposix_path_isabs(const char *path)
{
	if (path == NULL) return 0;
	if (path[0] == '/') return 1;
	if (path[0] == 0) return 0;
#ifdef _WIN32
	if (path[0] == IPATHSEP) return 1;
	if (isalpha(path[0]) && path[1] == ':') {
		if (path[2] == '/' || path[2] == '\\') return 1;
	}
#endif
	return 0;
}



//---------------------------------------------------------------------
// iposix_string_t - basic string definition
//---------------------------------------------------------------------
typedef struct
{
	char *p;
	int l;
	int m;
}	iposix_string_t;


//---------------------------------------------------------------------
// iposix_string_t interface
//---------------------------------------------------------------------
#define _istrlen(s) ((s)->l)
#define _istrch(s, i) (((i) >= 0)? ((s)->p)[i] : ((s)->p)[(s)->l + (i)])

static char *_istrset(iposix_string_t *s, const char *p, int max)
{
	assert((max > 0) && p && s);
	s->p = (char*)p;
	s->l = strlen(p);
	s->m = max;
	return (char*)p;
}

static char *_istrcat(iposix_string_t *s, const char *p) 
{
	char *p1;

	assert(s && p);
	for (p1 = (char*)p; p1[0]; p1++, s->l++) {
		if (s->l >= s->m) break;
		s->p[s->l] = p1[0];
	}
	return s->p;
}

static char *_istrcpy(iposix_string_t *s, const char *p) 
{
	assert(s && p);
	s->l = 0;
	return _istrcat(s, p);
}

static char *_istrcats(iposix_string_t *s1, const iposix_string_t *s2) 
{
	int i;
	assert(s1 && s2);
	for (i = 0; i < s2->l; i++, s1->l++) {
		if (s1->l >= s1->m) break;
		s1->p[s1->l] = s2->p[i];
	}
	return s1->p;
}

static char *_icstr(iposix_string_t *s) 
{
	assert(s);
	if (s->l >= s->m) s->l = s->m - 1;
	if (s->l < 0) s->l = 0;
	s->p[s->l] = 0;
	return s->p;
}

static char _istrc(const iposix_string_t *s, int pos)
{
	if (pos >= 0) return (pos > s->l)? 0 : s->p[pos];
	return (pos < -(s->l))? 0 : s->p[s->l + pos];
}

static char _istrchop(iposix_string_t *s)
{
	char ch = _istrc(s, -1);
	s->l--;
	if (s->l < 0) s->l = 0;
	return ch;
}

static char *_istrctok(iposix_string_t *s, const char *p)
{
	int i, k;

	assert(s && p);

	for (; _istrlen(s) > 0; ) {
		for (i = 0, k = 0; p[i] && k == 0; i++) {
			if (_istrc(s, -1) == p[i]) k++;
		}
		if (k == 0) break;
		_istrchop(s);
	}
	for (; _istrlen(s) > 0; ) {
		for (i = 0, k = 0; p[i] && k == 0; i++) {
			if (_istrc(s, -1) == p[i]) k++;
		}
		if (k) break;
		_istrchop(s);
	}

	return s->p;
}

static int _istrcmp(iposix_string_t *s, const char *p)
{
	int i;
	for (i = 0; i < s->l && ((char*)p)[i]; i++)
		if (_istrc(s, i) != ((char*)p)[i]) break;
	if (((char*)p)[i] == 0 && i == s->l) return 0;
	return 1;
}

static char *_istrcatc(iposix_string_t *s, char ch)
{
	char text[2] = " ";
	assert(s);
	text[0] = ch;
	return _istrcat(s, text);
}

static int istrtok(const char *p1, int *pos, const char *p2)
{
	int i, j, k, r;

	assert(p1 && pos && p2);

	for (i = *pos; p1[i]; i++) {
		for (j = 0, k = 0; p2[j] && k == 0; j++) {
			if (p1[i] == p2[j]) k++;
		}
		if (k == 0) break;
	}
	*pos = i;
	r = i;

	if (p1[i] == 0) return -1;
	for (; p1[i]; i++) {
		for (j = 0, k = 0; p2[j] && k == 0; j++) {
			if (p1[i] == p2[j]) k++;
		}
		if (k) break;
	}
	*pos = i;

	return r;
}


//---------------------------------------------------------------------
// normalize path
//---------------------------------------------------------------------
char *iposix_path_normal(const char *srcpath, char *path, int maxsize)
{
	int i, p, c, k, r;
	iposix_string_t s1, s2;
	char *p1, *p2;
	char pp2[3];

	assert(srcpath && path && maxsize > 0);

	if (srcpath[0] == 0) {
		if (maxsize > 0) path[0] = 0;
		return path;
	}

	for (p1 = (char*)srcpath; p1[0] && isspace((int)p1[0]); p1++);

	path[0] = 0;
	_istrset(&s1, path, maxsize);

	if (IPATHSEP == '\\') {
		pp2[0] = '/';
		pp2[1] = '\\';
		pp2[2] = 0;
	}	else {
		pp2[0] = '/';
		pp2[1] = 0;
	}

	p2 = pp2;

	if (p1[0] && p1[1] == ':' && (ISYSNAME == 'u' || ISYSNAME == 'w')) {
		_istrcatc(&s1, *p1++);
		_istrcatc(&s1, *p1++);
	}

	if (IPATHSEP == '/') {
		if (p1[0] == '/') _istrcatc(&s1, *p1++);
	}	
	else if (p1[0] == '/' || p1[0] == IPATHSEP) {
		_istrcatc(&s1, IPATHSEP);
		p1++;
	}

	r = (_istrc(&s1, -1) == IPATHSEP)? 1 : 0;
	srcpath = (const char*)p1;	

	for (i = 0, c = 0, k = 0; (p = istrtok(srcpath, &i, p2)) >= 0; k++) {
		s2.p = (char*)(srcpath + p);
		s2.l = s2.m = i - p;
		//_iputs(&s2); printf("*\n");
		if (_istrcmp(&s2, ".") == 0) continue;
		if (_istrcmp(&s2, "..") == 0) {
			if (c != 0) {
				_istrctok(&s1, (IPATHSEP == '\\')? "/\\:" : "/");
				c--;
				continue;
			}
			if (c == 0 && r) {
				continue;
			}
		}	else {
			c++;
		}
		_istrcats(&s1, &s2);
		_istrcatc(&s1, IPATHSEP);
	}
	if (_istrlen(&s1) == 0) {
		_istrcpy(&s1, ".");
	}	else {
		if (_istrc(&s1, -1) == IPATHSEP && c > 0) _istrchop(&s1);
	}
	return _icstr(&s1);
}


//---------------------------------------------------------------------
// join path
//---------------------------------------------------------------------
char *iposix_path_join(const char *p1, const char *p2, char *path, int len)
{
	iposix_string_t s;
	int maxsize = len;
	char *p, r;

	assert(p1 && p2 && maxsize > 0);

	for (; p1[0] && isspace((int)p1[0]); p1++);
	for (; p2[0] && isspace((int)p2[0]); p2++);
	r = 0;
	p = (char*)p2;
	if (IPATHSEP == '/') {
		if (p[0] == '/') r = 1;
	}	else {
		if (p[0] == '/' || p[0] == IPATHSEP) r = 1;
	}

	if (p[0] && p[1] == ':' && (ISYSNAME == 'u' || ISYSNAME == 'w')) 
		return iposix_path_normal(p2, path, maxsize);

	if (r && (p1[0] == 0 || p1[1] != ':' || p1[2])) 
		return iposix_path_normal(p2, path, maxsize);

	p = (char*)malloc(maxsize + 10);

	if (p == NULL) {
		return iposix_path_normal(p1, path, maxsize);
	}

	iposix_path_normal(p1, p, maxsize);
	_istrset(&s, p, maxsize);
	
	r = 1;
	if (_istrlen(&s) <= 2 && _istrc(&s, 1) == ':') r = 0;
	if (_istrc(&s, -1) == IPATHSEP) r = 0;
	if (_istrlen(&s) == 0) r = 0;
	if (r) _istrcatc(&s, IPATHSEP);

	_istrcat(&s, p2);
	iposix_path_normal(_icstr(&s), path, maxsize);
	free(p);

	return path;
}


// 绝对路径
char *iposix_path_abspath_u(const char *srcpath, char *path, int maxsize)
{
	char *base;
	base = (char*)malloc(IPOSIX_MAXBUFF * 2);
	if (base == NULL) return NULL;
	iposix_getcwd(base, IPOSIX_MAXPATH);
	iposix_path_join(base, srcpath, path, maxsize);
	free(base);
	return path;
}

#ifdef _WIN32
char *iposix_path_abspath_w(const char *srcpath, char *path, int maxsize)
{
	char *fname;
	DWORD hr = GetFullPathNameA(srcpath, maxsize, path, &fname);
	if (hr == 0) return NULL;
	return path;
}
#endif


// 绝对路径
char *iposix_path_abspath(const char *srcpath, char *path, int maxsize)
{
#ifdef _WIN32
	return iposix_path_abspath_w(srcpath, path, maxsize);
#else
	return iposix_path_abspath_u(srcpath, path, maxsize);
#endif
}

// 路径分割：从右向左找到第一个"/"分成两个字符串
int iposix_path_split(const char *path, char *p1, int l1, char *p2, int l2)
{
	int length, i, k;
	length = (int)strlen(path);

	for (i = length - 1; i >= 0; i--) {
		if (IPATHSEP == '/') {
			if (path[i] == '/') break;
		}	else {
			if (path[i] == '/' || path[i] == '\\') break;
		}
	}

	if (p1) {
		if (i < 0) {
			if (l1 > 0) p1[0] = 0;
		}	
		else if (i == 0) {
			p1[0] = '/';
			p1[1] = 0;
		}
		else {
			int size = i < l1 ? i : l1;
			memcpy(p1, path, size);
			if (size < l1) p1[size] = 0;
		}
	}

	k = length - i - 1;

	if (p2) {
		if (k <= 0) {
			if (l2 > 0) p2[0] = 0;
		}	else {
			int size = k < l2 ? k : l2;
			memcpy(p2, path + i + 1, k);
			if (size < l2) p2[size] = 0;
		}
	}

	return 0;
}


// 扩展分割：分割文件主名与扩展名
int iposix_path_splitext(const char *path, char *p1, int l1, 
	char *p2, int l2)
{
	int length, i, k, size;
	length = (int)strlen(path);
	for (i = length - 1, k = length; i >= 0; i--) {
		if (path[i] == '.') {
			k = i;
			break;
		}
		else if (IPATHSEP == '/') {
			if (path[i] == '/') break;

		}
		else {
			if (path[i] == '/' || path[i] == '\\') break;
		}
	}

	if (p1) {

		size = k < l1 ? k : l1;
		if (size > 0) memcpy(p1, path, size);
		if (size < l1) p1[size] = 0;
	}

	size = length - k - 1;
	if (size < 0) size = 0;
	size = size < l2 ? size : l2;

	if (p2) {
		if (size > 0) memcpy(p2, path + k + 1, size);
		if (size < l2) p2[size] = 0;
	}

	return 0;
}


//---------------------------------------------------------------------
// platform special
//---------------------------------------------------------------------

// cross os GetModuleFileName, returns size for success, -1 for error
int iposix_path_exepath(char *ptr, int size)
{
	int retval = -1;
#if defined(_WIN32)
	DWORD hr = GetModuleFileNameA(NULL, ptr, (DWORD)size);
	if (hr > 0) retval = (int)hr;
#elif defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
	int mib[4];
	size_t cb = (size_t)size;
	int hr;
	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_PATHNAME;
	mib[3] = -1;
	hr = sysctl(mib, 4, ptr, &cb, NULL, 0);
	if (hr >= 0) retval = (int)cb;
#elif defined(linux) || defined(__CYGWIN__)
	FILE *fp;
	fp = fopen("/proc/self/exename", "r");
	if (fp) {
		retval = fread(ptr, 1, size, fp);
		fclose(fp);
	}	else {
		retval = 0;
	}
#else
#endif
	if (retval >= 0 && retval < size) {
		ptr[retval] = '\0';
	}	else if (size > 0) {
		ptr[0] = '\0';
	}

	if (size > 0) ptr[size - 1] = 0;

	return retval;
}

// 取得进程可执行文件的目录
int iposix_path_execwd(char *ptr, int size)
{
	char *buffer;
	int retval;

	if (ptr) { 
		if (size > 0) ptr[0] = 0;
	}

	buffer = (char*)malloc(IPOSIX_MAXBUFF * 2);
	if (buffer == NULL) {
		return -1;
	}

	retval = iposix_path_exepath(buffer, IPOSIX_MAXBUFF * 2);
	
	if (retval < 0) {
		free(buffer);
		return -2;
	}

	iposix_path_split(buffer, ptr, size, NULL, IPOSIX_MAXPATH);

	free(buffer);

	return 0;
}


// 递归创建路径：直接从 ilog移植过来
int iposix_path_mkdir(const char *path, int mode)
{
	int i, len;
	char str[IPOSIX_MAXBUFF];

	len = (int)strlen(path);
	if (len > IPOSIX_MAXPATH) len = IPOSIX_MAXPATH;

	memcpy(str, path, len);
	str[len] = 0;

#ifdef _WIN32
	for (i = 0; i < len; i++) {
		if (str[i] == '/') str[i] = '\\';
	}
#endif

	for (i = 0; i < len; i++) {
		if (str[i] == '/' || str[i] == '\\') {
			str[i] = '\0';
			if (iposix_access(str, F_OK) != 0) {
				iposix_mkdir(str, mode);
			}
			str[i] = IPATHSEP;
		}
	}

	if (len > 0 && iposix_access(str, 0) != 0) {
		iposix_mkdir(str, mode);
	}

	return 0;
}


// 精简版取得可执行路径
const char *iposix_get_exepath(void)
{
	static int inited = 0;
	static char *ptr = NULL;
	if (inited == 0) {
		char *buffer = (char*)malloc(IPOSIX_MAXBUFF);
		char *b2;
		int size;
		if (buffer == NULL) {
			inited = -1;
			return "";
		}
		if (iposix_path_exepath(buffer, IPOSIX_MAXPATH) != 0) {
			free(buffer);
			inited = -1;
			return "";
		}
		size = (int)strlen(buffer);
		b2 = (char*)malloc(size + 1);
		if (b2 == NULL) {
			free(buffer);
			inited = -1;
			return "";
		}
		memcpy(b2, buffer, size + 1);
		free(buffer);
		ptr = b2;
		inited = 1;
	}
	if (inited < 0) return "";
	return ptr;
}

// 精简版取得可执行目录
const char *iposix_get_execwd(void)
{
	static int inited = 0;
	static char ptr[IPOSIX_MAXBUFF + 10];
	if (inited == 0) {
		if (iposix_path_execwd(ptr, IPOSIX_MAXPATH) != 0) {
			inited = -1;
			return "";
		}
		inited = 1;
	}
	if (inited < 0) return "";
	return ptr;
}

#ifdef _MSC_VER
#pragma warning(disable:4996)
#endif

// 文件路径格式化：
// out   - 输出路径，长度不小于 IPOSIX_MAXPATH
// base  - 根路径
// ...   - 后续的相对路径
// 返回  - out
// 假设可执行路径位于 /home/abc/work，那么：
// iposix_path_format(out, iposix_get_execwd(), "images/%s", "abc.jpg")
// 结果就是 /home/abc/work/images/abc.jpg
char *iposix_path_format(char *out, const char *root, const char *fmt, ...)
{
	char buffer[IPOSIX_MAXBUFF];
	va_list argptr;
	va_start(argptr, fmt);
	vsprintf(buffer, fmt, argptr);
	va_end(argptr);
	return iposix_path_join(root, buffer, out, IPOSIX_MAXPATH);
}



/*-------------------------------------------------------------------*/
/* System Utilities                                                  */
/*-------------------------------------------------------------------*/
#ifndef IDISABLE_SHARED_LIBRARY
	#if defined(__unix)
		#include <dlfcn.h>
	#endif
#endif

void *iposix_shared_open(const char *dllname)
{
#ifndef IDISABLE_SHARED_LIBRARY
	#ifdef __unix
	return dlopen(dllname, RTLD_LAZY);
	#else
	return (void*)LoadLibraryA(dllname);
	#endif
#else
	return NULL;
#endif
}

void *iposix_shared_get(void *shared, const char *name)
{
#ifndef IDISABLE_SHARED_LIBRARY
	#ifdef __unix
	return dlsym(shared, name);
	#else
	return (void*)GetProcAddress((HINSTANCE)shared, name);
	#endif
#else
	return NULL;
#endif
}

void iposix_shared_close(void *shared)
{
#ifndef IDISABLE_SHARED_LIBRARY
	#ifdef __unix
	dlclose(shared);
	#else
	FreeLibrary((HINSTANCE)shared);
	#endif
#endif
}

/* load file content */
void *iposix_file_load_content(const char *filename, long *size)
{
	size_t length, remain;
	char *ptr, *out;
	FILE *fp;

	if ((fp = fopen(filename, "rb")) == NULL) {
        if (size) size[0] = 0;
        return NULL;
    }
    
    fseek(fp, 0, SEEK_END);
    length = ftell(fp);
    fseek(fp, 0, SEEK_SET);
	
    // avoid zero-size file returns null
	ptr = (char*)malloc(length + 8);

	if (ptr == NULL) {
		fclose(fp);
		if (size) size[0] = 0;
		return NULL;
	}

	for (remain = length, out = ptr; remain > 0; ) {
		size_t ret = fread(out, 1, remain, fp);
		if (ret == 0) break;
        remain -= ret;
        out += ret;
	}

	fclose(fp);
	
	if (size) size[0] = length;

	return ptr;
}


/* save file content */
int iposix_file_save_content(const char *filename, const void *data, long size)
{
	const char *ptr = (const char*)data;
	FILE *fp;
	int hr = 0;
	if ((fp = fopen(filename, "wb")) == NULL) return -1;
	for (; size > 0; ) {
		long written = (long)fwrite(ptr, 1, size, fp);
		if (written <= 0) {
			hr = -2;
			break;
		}
		size -= written;
		ptr += written;
	}
	fclose(fp);
	return hr;
}



#endif




