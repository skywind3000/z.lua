//=====================================================================
//
// iposix.h - posix file system accessing
//
// NOTE:
// for more information, please see the readme file.
//
//=====================================================================
#ifndef __IPOSIX_H__
#define __IPOSIX_H__

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif


/*-------------------------------------------------------------------*/
/* C99 Compatible                                                    */
/*-------------------------------------------------------------------*/
#if defined(linux) || defined(__linux) || defined(__linux__)
#ifdef _POSIX_C_SOURCE
#if _POSIX_C_SOURCE < 200112L
#undef _POSIX_C_SOURCE
#endif
#endif

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200112L
#endif

#ifdef _GNU_SOURCE
#undef _GNU_SOURCE
#endif

#ifdef _BSD_SOURCE
#undef _BSD_SOURCE
#endif

#ifdef __BSD_VISIBLE
#undef __BSD_VISIBLE
#endif

#ifdef _XOPEN_SOURCE
#undef _XOPEN_SOURCE
#endif

#define _GNU_SOURCE 1
#define _BSD_SOURCE 1
#define __BSD_VISIBLE 1
#define _XOPEN_SOURCE 600
#endif


#ifndef IDISABLE_FILE_SYSTEM_ACCESS
//---------------------------------------------------------------------
// Global Definition
//---------------------------------------------------------------------
#ifndef __INTEGER_32_BITS__
#define __INTEGER_32_BITS__
#if defined(__UINT32_TYPE__) && defined(__UINT32_TYPE__)
	typedef __UINT32_TYPE__ ISTDUINT32;
	typedef __INT32_TYPE__ ISTDINT32;
#elif defined(__UINT_FAST32_TYPE__) && defined(__INT_FAST32_TYPE__)
	typedef __UINT_FAST32_TYPE__ ISTDUINT32;
	typedef __INT_FAST32_TYPE__ ISTDINT32;
#elif defined(_WIN64) || defined(WIN64) || defined(__amd64__) || \
	defined(__x86_64) || defined(__x86_64__) || defined(_M_IA64) || \
	defined(_M_AMD64)
	typedef unsigned int ISTDUINT32;
	typedef int ISTDINT32;
#elif defined(_WIN32) || defined(WIN32) || defined(__i386__) || \
	defined(__i386) || defined(_M_X86)
	typedef unsigned long ISTDUINT32;
	typedef long ISTDINT32;
#elif defined(__MACOS__)
	typedef UInt32 ISTDUINT32;
	typedef SInt32 ISTDINT32;
#elif defined(__APPLE__) && defined(__MACH__)
	#include <sys/types.h>
	typedef u_int32_t ISTDUINT32;
	typedef int32_t ISTDINT32;
#elif defined(__BEOS__)
	#include <sys/inttypes.h>
	typedef u_int32_t ISTDUINT32;
	typedef int32_t ISTDINT32;
#elif (defined(_MSC_VER) || defined(__BORLANDC__)) && (!defined(__MSDOS__))
	typedef unsigned __int32 ISTDUINT32;
	typedef __int32 ISTDINT32;
#elif defined(__GNUC__) && (__GNUC__ > 3)
	#include <stdint.h>
	typedef uint32_t ISTDUINT32;
	typedef int32_t ISTDINT32;
#else 
	typedef unsigned long ISTDUINT32; 
	typedef long ISTDINT32;
#endif
#endif


#if (defined(__APPLE__) && defined(__MACH__)) || defined(__MACOS__)
#ifndef __unix
#define __unix 1
#endif
#endif

#if defined(__unix__) || defined(unix) || defined(__linux)
#ifndef __unix
#define __unix 1
#endif
#endif

#include <stdio.h>
#ifdef __unix
#include <unistd.h>
#define IPATHSEP '/'
#else
#include <direct.h>
#if defined(_WIN32)
#define IPATHSEP '\\'
#else
#define IPATHSEP '/'
#endif
#endif


#ifndef __IINT8_DEFINED
#define __IINT8_DEFINED
typedef char IINT8;
#endif

#ifndef __IUINT8_DEFINED
#define __IUINT8_DEFINED
typedef unsigned char IUINT8;
#endif

#ifndef __IUINT16_DEFINED
#define __IUINT16_DEFINED
typedef unsigned short IUINT16;
#endif

#ifndef __IINT16_DEFINED
#define __IINT16_DEFINED
typedef short IINT16;
#endif

#ifndef __IINT32_DEFINED
#define __IINT32_DEFINED
typedef ISTDINT32 IINT32;
#endif

#ifndef __IUINT32_DEFINED
#define __IUINT32_DEFINED
typedef ISTDUINT32 IUINT32;
#endif

#ifndef __IINT64_DEFINED
#define __IINT64_DEFINED
#if defined(_MSC_VER) || defined(__BORLANDC__)
typedef __int64 IINT64;
#else
typedef long long IINT64;
#endif
#endif

#ifndef __IUINT64_DEFINED
#define __IUINT64_DEFINED
#if defined(_MSC_VER) || defined(__BORLANDC__)
typedef unsigned __int64 IUINT64;
#else
typedef unsigned long long IUINT64;
#endif
#endif

#if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
	#ifndef _WIN32
	#define _WIN32
	#endif
#endif


#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------
// Posix Stat
//---------------------------------------------------------------------
#define ISTAT_IFMT		0170000		// file type mask
#define ISTAT_IFIFO		0010000		// named pipe (fifo) 
#define ISTAT_IFCHR		0020000		// charactor special
#define ISTAT_IFDIR		0040000		// directory
#define ISTAT_IFBLK		0060000		// block special
#define ISTAT_IFREG		0100000		// regular
#define ISTAT_IFLNK		0120000		// symbolic link
#define ISTAT_IFSOCK	0140000		// socket
#define ISTAT_IFWHT		0160000		// whiteout
#define ISTAT_ISUID		0004000		// set user id on execution
#define ISTAT_ISGID		0002000		// set group id on execution
#define ISTAT_ISVXT		0001000		// swapped text even after use
#define ISTAT_IRWXU		0000700		// owner RWX mask
#define ISTAT_IRUSR		0000400		// owner read permission
#define ISTAT_IWUSR		0000200		// owner writer permission
#define ISTAT_IXUSR		0000100		// owner execution permission
#define ISTAT_IRWXG		0000070		// group RWX mask
#define ISTAT_IRGRP		0000040		// group read permission
#define ISTAT_IWGRP		0000020		// group write permission
#define ISTAT_IXGRP		0000010		// group execution permission
#define ISTAT_IRWXO		0000007		// other RWX mask
#define ISTAT_IROTH		0000004		// other read permission
#define ISTAT_IWOTH		0000002		// other writer permission
#define ISTAT_IXOTH		0000001		// other execution permission

#define ISTAT_ISFMT(m, t)	(((m) & ISTAT_IFMT) == (t))
#define ISTAT_ISDIR(m)		ISTAT_ISFMT(m, ISTAT_IFDIR)
#define ISTAT_ISCHR(m)		ISTAT_ISFMT(m, ISTAT_IFCHR)
#define ISTAT_ISBLK(m)		ISTAT_ISFMT(m, ISTAT_IFBLK)
#define ISTAT_ISREG(m)		ISTAT_ISFMT(m, ISTAT_IFREG)
#define ISTAT_ISFIFO(m)		ISTAT_ISFMT(m, ISTAT_IFIFO)
#define ISTAT_ISLNK(m)		ISTAT_ISFMT(m, ISTAT_IFLNK)
#define ISTAT_ISSOCK(m)		ISTAT_ISFMT(m, ISTAT_IFSOCK)
#define ISTAT_ISWHT(m)		ISTAT_ISFMT(m, ISTAT_IFWHT)

struct IPOSIX_STAT
{
	IUINT32 st_mode;
	IUINT64 st_ino;
	IUINT32 st_dev;
	IUINT32 st_nlink;
	IUINT32 st_uid;
	IUINT32 st_gid;
	IUINT64 st_size;
	IUINT32 atime;
	IUINT32 mtime;
	IUINT32 ctime;
	IUINT32 st_blocks;
	IUINT32 st_blksize;
	IUINT32 st_rdev;
	IUINT32 st_flags;
};

typedef struct IPOSIX_STAT iposix_stat_t;

#define IPOSIX_MAXPATH		1024
#define IPOSIX_MAXBUFF		((IPOSIX_MAXPATH) + 8)


// returns 0 for success, -1 for error
int iposix_stat(const char *path, iposix_stat_t *ostat);

// returns 0 for success, -1 for error
int iposix_lstat(const char *path, iposix_stat_t *ostat);

// returns 0 for success, -1 for error
int iposix_fstat(int fd, iposix_stat_t *ostat);

// get current directory
char *iposix_getcwd(char *path, int size);

// create directory
int iposix_mkdir(const char *path, int mode);

// change directory
int iposix_chdir(const char *path);

#ifndef F_OK
#define F_OK		0
#endif

#ifndef X_OK
#define X_OK		1
#endif

#ifndef W_OK
#define W_OK		2
#endif

#ifndef R_OK
#define R_OK		4
#endif

// check access
int iposix_access(const char *path, int mode);


// returns 1 for true 0 for false, -1 for not exist
int iposix_path_isdir(const char *path);

// returns 1 for true 0 for false, -1 for not exist
int iposix_path_isfile(const char *path);

// returns 1 for true 0 for false, -1 for not exist
int iposix_path_islink(const char *path);

// returns 1 for true 0 for false
int iposix_path_exists(const char *path);

// returns file size, -1 for error
IINT64 iposix_path_getsize(const char *path);


//---------------------------------------------------------------------
// Posix Path
//---------------------------------------------------------------------

// 是否是绝对路径，如果是的话返回1，否则返回0
int iposix_path_isabs(const char *path);

// 绝对路径
char *iposix_path_abspath(const char *srcpath, char *path, int maxsize);

// 归一化路径：去掉重复斜杠，以及处理掉".", ".."等。
char *iposix_path_normal(const char *srcpath, char *path, int maxsize);

// 连接路径
char *iposix_path_join(const char *p1, const char *p2, char *path, int len);

// 路径分割：从右向左找到第一个"/"分成两个字符串
int iposix_path_split(const char *path, char *p1, int l1, char *p2, int l2);

// 扩展分割：分割文件主名与扩展名
int iposix_path_splitext(const char *path, char *p1, int l1, 
	char *p2, int l2);


//---------------------------------------------------------------------
// platform special
//---------------------------------------------------------------------

// 取得进程可执行文件的文件名
int iposix_path_exepath(char *ptr, int size);

// 取得进程可执行文件的目录
int iposix_path_execwd(char *ptr, int size);

// 递归创建路径
int iposix_path_mkdir(const char *path, int mode);

// 精简版取得可执行路径
const char *iposix_get_exepath(void);

// 精简版取得可执行目录
const char *iposix_get_execwd(void);


// 文件路径格式化：
// out   - 输出路径，长度不小于 IPOSIX_MAXPATH
// root  - 根路径
// ...   - 后续的相对路径
// 返回  - out
// 假设可执行路径位于 /home/abc/work，那么：
// iposix_path_format(out, iposix_get_execwd(), "images/%s", "abc.jpg")
// 结果就是 /home/abc/work/images/abc.jpg
char *iposix_path_format(char *out, const char *root, const char *fmt, ...);



//---------------------------------------------------------------------
// System Utilities
//---------------------------------------------------------------------

#ifndef IDISABLE_SHARED_LIBRARY

/* LoadLibraryA */
void *iposix_shared_open(const char *dllname);

/* GetProcAddress */
void *iposix_shared_get(void *shared, const char *name);

/* FreeLibrary */
void iposix_shared_close(void *shared);

#endif

#ifndef IDISABLE_FILE_SYSTEM_ACCESS

/* load file content, use free to dispose */
void *iposix_file_load_content(const char *filename, long *size);

/* save file content */
int iposix_file_save_content(const char *filename, const void *data, long size);

/* cross os GetModuleFileName, returns size for success, -1 for error */
int iposix_get_proc_pathname(char *ptr, int size);

#endif



#ifdef __cplusplus
}
#endif


#endif


#endif




