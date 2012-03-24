d=`perl -e 'require SVN::Core' 2>&1 | head -1 | sed 's/.*\(\/usr[^ ]*SVN\).*/\1/'`
[[ $d ]] && find $d -name \*.so | while read f; do
	d=`dirname $f` f=`basename $f`
	mv $d/{,lib}$f
	ld -s -shared -o$d/$f -{L,rpath=}$d -l${f%.so} -lsvn_swig_perl-1
done

file /bin/bash | grep -q x86-64 && git apply --directory=/ <<'EOF'
--- a/usr/include/python2.6/pyconfig.h
+++ b/usr/include/python2.6/pyconfig.h
@@ -348,6 +348,9 @@
    add some flags for configuration and compilation to enable this mode. (For
    Solaris and Linux, the necessary defines are already defined.) */
 /* #undef HAVE_LARGEFILE_SUPPORT */
+#if 4 == __SIZEOF_LONG__
+#define HAVE_LARGEFILE_SUPPORT 1
+#endif
 
 /* Define to 1 if you have the `lchflags' function. */
 /* #undef HAVE_LCHFLAGS */
@@ -863,6 +866,9 @@
 
 /* Define as the integral type used for Unicode representation. */
 /* #undef PY_UNICODE_TYPE */
+#if 4 == __SIZEOF_LONG__
+#define PY_UNICODE_TYPE unsigned long
+#endif
 
 /* Define if you want to build an interpreter with many run-time checks. */
 /* #undef Py_DEBUG */
@@ -901,10 +907,10 @@
 #define SIZEOF_INT 4
 
 /* The size of `long', as computed by sizeof. */
-#define SIZEOF_LONG 8
+#define SIZEOF_LONG __SIZEOF_LONG__
 
 /* The size of `long double', as computed by sizeof. */
-#define SIZEOF_LONG_DOUBLE 16
+#define SIZEOF_LONG_DOUBLE __SIZEOF_LONG_DOUBLE__
 
 /* The size of `long long', as computed by sizeof. */
 #define SIZEOF_LONG_LONG 8
@@ -916,22 +922,22 @@
 #define SIZEOF_PID_T 4
 
 /* The number of bytes in a pthread_t. */
-#define SIZEOF_PTHREAD_T 8
+#define SIZEOF_PTHREAD_T SIZEOF_LONG
 
 /* The size of `short', as computed by sizeof. */
 #define SIZEOF_SHORT 2
 
 /* The size of `size_t', as computed by sizeof. */
-#define SIZEOF_SIZE_T 8
+#define SIZEOF_SIZE_T SIZEOF_LONG
 
 /* The number of bytes in a time_t. */
-#define SIZEOF_TIME_T 8
+#define SIZEOF_TIME_T SIZEOF_LONG
 
 /* The size of `uintptr_t', as computed by sizeof. */
-#define SIZEOF_UINTPTR_T 8
+#define SIZEOF_UINTPTR_T SIZEOF_LONG
 
 /* The size of `void *', as computed by sizeof. */
-#define SIZEOF_VOID_P 8
+#define SIZEOF_VOID_P SIZEOF_LONG
 
 /* The size of `wchar_t', as computed by sizeof. */
 #define SIZEOF_WCHAR_T 4
@@ -981,7 +987,9 @@
 /* #undef USE_TOOLBOX_OBJECT_GLUE */
 
 /* Define if a va_list is an array of some kind */
+#if 4 != __SIZEOF_LONG__
 #define VA_LIST_IS_ARRAY 1
+#endif
 
 /* Define if you want SIGFPE handled (see Include/pyfpe.h). */
 #define WANT_SIGFPE_HANDLER 1
@@ -1031,6 +1039,9 @@
 
 /* Define if arithmetic is subject to x87-style double rounding issue */
 /* #undef X87_DOUBLE_ROUNDING */
+#if 4 == __SIZEOF_LONG__
+#define X87_DOUBLE_ROUNDING 1
+#endif
 
 /* Define on OpenBSD to activate all library features */
 /* #undef _BSD_SOURCE */
EOF
