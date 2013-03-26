// vi:noai:sw=4

#ifndef COMMON__H
#define COMMON__H

#include <iostream>

#define LIKELY(x)   __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)

#define PRINT(output) \
    do { \
        std::cout \
            << __FILE__ << ":" << __LINE__ << " " \
            << "" output \
            << std::endl; \
    } while (false)

#define WARNING(output) \
    do { \
        std::cerr \
            << __FILE__ << ":" << __LINE__ << " " \
            << "" output  \
            << std::endl; \
    } while (false)

#define ERROR(output) \
    do { \
        std::cerr \
            << __FILE__ << ":" << __LINE__ << " " \
            << "" output  \
            << std::endl; \
    } while (false)

#define FATAL(output) \
    do { \
        std::cerr \
            << __FILE__ << ":" << __LINE__ << " " \
            << "" output  \
            << std::endl; \
        std::terminate(); \
    } while (false)

// ENFORCE and variants never get compiled out.
#define ENFORCE(condition, output) \
    do { \
        if (!LIKELY(condition)) { \
            std::cerr \
                << __FILE__ << ":" << __LINE__ << " " \
                << "" output  \
                << "  (("#condition"))" \
                << std::endl; \
            std::terminate(); \
        } \
    } while (false)

#define ENFORCE_SYS(condition, output) \
    ENFORCE(condition, "" output << " (" << ::strerror(errno) << ")")

// ASSERT and variants may be compiled out.
#if 1
#  define ASSERT(condition, output) \
    do { \
        if (!LIKELY(condition)) { \
            std::cerr \
                << __FILE__ << ":" << __LINE__ << " " \
                << "" output  \
                << "  (("#condition"))" \
                << std::endl; \
            std::terminate(); \
        } \
    } while (false)

#  define ASSERT_SYS(condition, output) \
    ASSERT(condition, "" output << " (" << ::strerror(errno) << ")")
#else
#  define ASSERT(condition, output) \
    do { } while (false)
#  define ASSERT_SYS(condition, output) \
    do { } while (false)
#endif

#endif // COMMON__H
