#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <linux/limits.h>

#include "imembase.c"


//----------------------------------------------------------------------
// INLINE
//----------------------------------------------------------------------
#ifndef INLINE
#if defined(__GNUC__)

#if (__GNUC__ > 3) || ((__GNUC__ == 3) && (__GNUC_MINOR__ >= 1))
#define INLINE         __inline__ __attribute__((always_inline))
#else
#define INLINE         __inline__
#endif

#elif (defined(_MSC_VER) || defined(__WATCOMC__))
#define INLINE __inline
#else
#define INLINE 
#endif
#endif

#if (!defined(__cplusplus)) && (!defined(inline))
#define inline INLINE
#endif


//---------------------------------------------------------------------
// get environ
//---------------------------------------------------------------------
static ib_string* os_getenv(const char *name)
{
	char *p = getenv(name);
	if (p == NULL) {
		return NULL;
	}
	ib_string *text = ib_string_new();
	ib_string_assign(text, p);
	return text;
}


//---------------------------------------------------------------------
// get data file
//---------------------------------------------------------------------
static inline const char *get_data_file(void)
{
	static ib_string *text = NULL;
	if (text != NULL) {
		return text->ptr;
	}
	text = os_getenv("_ZL_DATA");
	if (text) {
		return text->ptr;
	}
	text = os_getenv("HOME");
	if (text == NULL) {
		text = os_getenv("USERPROFILE");
	}
	if (text == NULL) {
		return NULL;
	}
	ib_string_append(text, "/.zlua");
	return text->ptr;
}

int main(int argc, char *argv[])
{
	if (argc <= 1) {
		printf("Hello, World !!\n");
		printf("data: %s\n", get_data_file());
		return 0;
	}
	if (strcmp(argv[1], "--add") == 0) {
		if (argc >= 3) {
		}
	}
	return 0;
}


