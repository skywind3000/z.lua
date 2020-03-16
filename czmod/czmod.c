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
#include <time.h>

#if defined(_WIN32) || defined(_WIN64) || defined(WIN32) || defined(WIN64)
#include <windows.h>
#elif defined(__linux)
// #include <linux/limits.h>
#endif

#include "iposix.c"
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
	text = os_getenv("_ZL_DATA2");
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

ib_array* ib_array_new_items(void)
{
	return ib_array_new((void (*)(void*))item_delete);
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
	else {
		ib_array *lines = ib_string_split_c(content, '\n');
		int size = ib_array_size(lines);
		int i;
		ib_array *items = ib_array_new_items();
		for (i = 0; i < size; i++) {
			ib_string *text = (ib_string*)ib_array_index(lines, i);
			int p1 = ib_string_find_c(text, '|', 0);
			if (p1 >= 0) {
				int p2 = ib_string_find_c(text, '|', p1 + 1);
				if (p2 >= 0) {
					uint32_t timestamp;
					int rank;
					text->ptr[p1] = 0;
					text->ptr[p2] = 0;
					rank = (int)atoi(text->ptr + p1 + 1);
					timestamp = (uint32_t)strtoul(text->ptr + p2 + 1, NULL, 10);
					PathItem *ni = item_new(text->ptr, rank, timestamp);
					ib_array_push(items, ni);
				}
			}
		}
		ib_array_delete(lines);
		return items;
	}
	return NULL;
}


//---------------------------------------------------------------------
// save data
//---------------------------------------------------------------------
void data_save(const char *filename, ib_array *items)
{
	ib_string *tmpname = ib_string_new_from(filename);
	FILE *fp;
	while (1) {
		char tmp[100];
		ib_string_assign(tmpname, filename);
		sprintf(tmp, ".%u%03u%d", (uint32_t)time(NULL), 
				(uint32_t)(clock() % 1000), rand() % 10000);
		ib_string_append(tmpname, tmp);
		if (iposix_path_isdir(tmpname->ptr) < 0) break;
	}
	fp = fopen(tmpname->ptr, "w");
	if (fp) {
		int size = ib_array_size(items);
		int i;
		for (i = 0; i < size; i++) {
			PathItem *item = (PathItem*)ib_array_index(items, i);
			fprintf(fp, "%s|%u|%u\n",
				item->path->ptr, item->rank, item->timestamp);
		}
		fclose(fp);
	#ifdef _WIN32
		ReplaceFileA(filename, tmpname->ptr, NULL, 2, NULL, NULL);
	#else
		rename(tmpname->ptr, filename);
	#endif
	}
	ib_string_delete(tmpname);
}


//---------------------------------------------------------------------
// insert data
//---------------------------------------------------------------------
void data_add(ib_array *items, const char *path)
{
	ib_string *target = ib_string_new_from(path);
	int i = 0, size, found = 0;
#if defined(_WIN32)
	for (i = 0; i < target->size; i++) {
		if (target->ptr[i] == '/') target->ptr[i] = '\\';
		else {
			target->ptr[i] = (char)tolower(target->ptr[i]);
		}
	}
#endif
	size = ib_array_size(items);
	for (i = 0; i < size; i++) {
		PathItem *item = (PathItem*)ib_array_index(items, i);
		int equal = 0;
	#if defined(_WIN32)
		if (item->path->size == target->size) {
			char *src = item->path->ptr;
			char *dst = target->ptr;
			int avail = target->size;
			for (; avail > 0; src++, dst++, avail--) {
				if (tolower(src[0]) != dst[0]) break;
			}
			equal = (avail == 0)? 1 : 0;
		}
	#else
		if (ib_string_compare(item->path, target) == 0) {
			equal = 1;
		}
	#endif
		if (equal) {
			found = 1;
			item->rank++;
			item->timestamp = (uint32_t)time(NULL);
		}
	}
	if (!found) {
		PathItem *ni = item_new(target->ptr, 1, (uint32_t)time(NULL));
		ib_array_push(items, ni);
	}
	ib_string_delete(target);
}


//---------------------------------------------------------------------
// add to database
//---------------------------------------------------------------------
void z_add(const char *newpath)
{
	const char *data = get_data_file();
	ib_array *items = data_load(data);
	if (items == NULL) {
		items = ib_array_new_items();
	}
	data_add(items, newpath);
	data_save(data, items);
	ib_array_delete(items);
}


//---------------------------------------------------------------------
// main entry
//---------------------------------------------------------------------
int main(int argc, char *argv[])
{
	if (argc <= 1) {
		int i;
		printf("begin\n");
		clock_t ts = (uint64_t)clock();
		for (i = 0; i < 1000; i++) {
			z_add("/tmp");
		}
		ts = clock() - ts;
		ts = (ts * 1000) / CLOCKS_PER_SEC;
		printf("finished: %d ms\n", (int)ts);
		return 0;
	}
	if (strcmp(argv[1], "--add") == 0) {
		if (argc >= 3) {
			z_add(argv[2]);
		}
	}
	return 0;
}


