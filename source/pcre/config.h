#if defined(EWINDOWS) || defined(EDOS)
#	include "config.h.windows"
#else
#    if defined(EUNIX)
#    	include "config.h.unix"
#    else
#       error **
#       error ** No OS set!                              
#	error ** Please run configure and make utilities 
#	error ** from this directory s parent
#	error ** 
#    endif
#endif

#undef DEBUG
