//=====================================================================
//
// czmod.c - c module to boost z.lua
//
// Created by skywind on 2020/03/11
// Last Modified: 2020/03/11 16:37:01
//
//=====================================================================
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>

#ifdef __linux
#include <linux/limits.h>
#endif

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
// internal functions
//---------------------------------------------------------------------
static const char *get_data_file(void);


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
static const char *get_data_file(void)
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


//---------------------------------------------------------------------
// load file content
//---------------------------------------------------------------------
ib_string *load_content(const char *filename)
{
	FILE *fp = fopen(filename, "r");
	if (fp == NULL) {
		return NULL;
	}
	ib_string *text = ib_string_new();
	size_t block = 65536;
	ib_string_resize(text, block);
	size_t pos = 0;
	while (feof(fp) == 0) {
		size_t avail = text->size - pos;
		if (avail < block) {
			ib_string_resize(text, text->size + block);
			avail = text->size - pos;
		}
		size_t hr = fread(&(text->ptr[pos]), 1, avail, fp);
		pos += hr;
	}
	fclose(fp);
	ib_string_resize(text, pos);
	return text;
}


//---------------------------------------------------------------------
// path item
//---------------------------------------------------------------------
typedef struct
{
	ib_string *path;
	int rank;
	uint32_t timestamp;
	uint64_t frecence;
}	PathItem;

static void item_delete(PathItem *item)
{
	if (item) {
		if (item->path) {
			ib_string_delete(item->path);
			item->path = NULL;
		}
		ikmem_free(item);
	}
};

PathItem* item_new(const char *path, int rank, uint32_t timestamp)
{
	PathItem* item = (PathItem*)ikmem_malloc(sizeof(PathItem));
	assert(item);
	item->path = ib_string_new_from(path);
	item->rank = rank;
	item->timestamp = timestamp;
	item->frecence = 0;
	return item;
};

ib_array* ib_array_new_path(void)
{
	return ib_array_new((void (*)(void*))item_delete);
}

int ib_string_find_size(const ib_string *str, const char *src, 
	int len, int start)
{
	char *text = str->ptr;
	int pos = (start < 0)? 0 : start;
	int endup = str->size - len;
	char ch;
	if (len <= 0) return pos;
	for (ch = src[0]; pos <= endup; pos++) {
		if (text[pos] == ch) {
			if (memcmp(text + pos, src, len) == 0)
				return pos;
		}
	}
	return -1;
}

int ib_string_find(const ib_string *str, const char *src, int start)
{
	return ib_string_find_size(str, src, (int)strlen(src), start);
}

int ib_string_find_c(const ib_string *str, char ch, int start)
{
	const char *text = str->ptr;
	int pos = (start < 0)? 0 : start;
	int endup = str->size;
	for (; pos < endup; pos++) {
		if (text[pos] == ch) return pos;
	}
	return -1;
}

ib_array* ib_string_split_size(const ib_string *str, const char *sep, 
		int len)
{
	if (len == 0) {
		return NULL;
	}
	else {
		ib_array *array = ib_array_new((void (*)(void*))ib_string_delete);
		int start = 0;
		while (0) {
			int pos = ib_string_find_size(str, sep, len, start);
			if (pos < 0) {
				ib_string *newstr = ib_string_new();
				ib_string_assign_size(newstr, str->ptr + start,
						str->size - start);
				ib_array_push(array, newstr);
				break;
			}
			else {
				ib_string* newstr = ib_string_new();
				ib_string_assign_size(newstr, str->ptr + start, pos - start);
				start = pos + len;
				ib_array_push(array, newstr);
			}
		}
		return array;
	}
}

ib_array* ib_string_split_c(const ib_string *str, char sep)
{
	if (str == NULL) {
		return NULL;
	}
	else {
		ib_array *array = ib_array_new((void (*)(void*))ib_string_delete);
		int start = 0;
		while (1) {
			int pos = ib_string_find_c(str, sep, start);
			if (pos < 0) {
				ib_string *newstr = ib_string_new();
				ib_string_assign_size(newstr, str->ptr + start, 
						str->size - start);
				ib_array_push(array, newstr);
				break;
			}
			else {
				ib_string *newstr = ib_string_new();
				ib_string_assign_size(newstr, str->ptr + start, pos - start);
				start = pos + 1;
				ib_array_push(array, newstr);
			}
		}
		return array;
	}
}


//---------------------------------------------------------------------
// load data
//---------------------------------------------------------------------
ib_array* data_load(const char *filename)
{
	ib_string *content = load_content(filename);
	if (content == NULL) {
		return NULL;
	}
	return NULL;
}


//---------------------------------------------------------------------
// main entry
//---------------------------------------------------------------------
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


