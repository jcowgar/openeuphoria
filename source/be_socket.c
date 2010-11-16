/*****************************************************************************/
/*      (c) Copyright - See License.txt       */
/*****************************************************************************/

#include <stdio.h>
#include <stdlib.h>



#include "alldefs.h"
#include "be_alloc.h"
#include "be_runtime.h"
#include "be_socket.h"

// Accessors for the socket sequence given to many functions
#define SOCK_SOCKET   1
#define SOCK_SOCKADDR 2

#define BUFF_SIZE 1024

#define IS_SOCKET(sock) \
	(IS_SEQUENCE(sock) && SEQ_PTR(sock)->length == 2 && \
	IS_ATOM_INT(SEQ_PTR(sock)->base[SOCK_SOCKET]) && \
	IS_ATOM(SEQ_PTR(sock)->base[SOCK_SOCKADDR]))

#define ERR_OK                     0
#define ERR_ACCESS                -1
#define ERR_ADDRINUSE             -2
#define ERR_ADDRNOTAVAIL          -3
#define ERR_AFNOSUPPORT           -4
#define ERR_AGAIN                 -5
#define ERR_ALREADY               -6
#define ERR_CONNABORTED           -7
#define ERR_CONNREFUSED           -8
#define ERR_CONNRESET             -9
#define ERR_DESTADDRREQ           -10
#define ERR_FAULT                 -11
#define ERR_HOSTUNREACH           -12
#define ERR_INPROGRESS            -13
#define ERR_INTR                  -14
#define ERR_INVAL                 -15
#define ERR_IO                    -16
#define ERR_ISCONN                -17
#define ERR_ISDIR                 -18
#define ERR_LOOP                  -19
#define ERR_MFILE                 -20
#define ERR_MSGSIZE               -21
#define ERR_NAMETOOLONG           -22
#define ERR_NETDOWN               -23
#define ERR_NETRESET              -24
#define ERR_NETUNREACH            -25
#define ERR_NFILE                 -26
#define ERR_NOBUFS                -27
#define ERR_NOENT                 -28
#define ERR_NOTCONN               -29
#define ERR_NOTDIR                -30
#define ERR_NOTINITIALISED        -31
#define ERR_NOTSOCK               -32
#define ERR_OPNOTSUPP             -33
#define ERR_PROTONOSUPPORT        -34
#define ERR_PROTOTYPE             -35
#define ERR_ROFS                  -36
#define ERR_SHUTDOWN              -37
#define ERR_SOCKTNOSUPPORT        -38
#define ERR_TIMEDOUT              -39
#define ERR_WOULDBLOCK            -40

#define ESOCK_UNDEFINED_VALUE	-9999
#define ESOCK_UNKNOWN_FLAG	-9998
#define ESOCK_TYPE_AF		1
#define ESOCK_TYPE_TYPE		2
#define ESOCK_TYPE_OPTION	3

#define EAF_UNSPEC		6
#define EAF_UNIX		1
#define EAF_INET		2
#define EAF_INET6		3
#define EAF_APPLETALK		4
#define EAF_BTH			5

#define ESOCK_STREAM		1
#define ESOCK_DGRAM		2
#define ESOCK_RAW		3
#define ESOCK_RDM		4
#define ESOCK_SEQPACKET		5

#define ESOL_SOCKET		1
#define ESO_DEBUG		2
#define ESO_ACCEPTCONN		3
#define ESO_REUSEADDR		4
#define ESO_KEEPALIVE		5
#define ESO_DONTROUTE		6
#define ESO_BROADCAST		7
#define ESO_LINGER		8
#define ESO_SNDBUF		9
#define ESO_RCVBUF		10
#define ESO_SNDLOWAT		11
#define ESO_RCVLOWAT		12
#define ESO_SNDTIMEO		13
#define ESO_RCVTIMEO		14
#define ESO_ERROR		15
#define ESO_TYPE		16
#define ESO_OOBINLINE		17
#define ESO_USELOOPBACK		18
#define ESO_DONTLINGER		19
#define ESO_REUSEPORT		20
#define ESO_CONNDATA		21
#define ESO_CONNOPT		22
#define ESO_DISCDATA		23
#define ESO_DISCOPT		24
#define ESO_CONNDATALEN		25
#define ESO_CONNOPTLEN		26
#define ESO_DISCDATALEN		27
#define ESO_DISCOPTLEN		28
#define ESO_OPENTYPE		29
#define ESO_MAXDG		30
#define ESO_MAXPATHDG		31
#define ESO_SYNCHRONOUS_ALTERT	32
#define ESO_SYNCHRONOUS_NONALERT 33
#define ESO_SNDBUFFORCE		34
#define ESO_RCVBUFFORCE		35
#define ESO_NO_CHECK		36
#define ESO_PRIORITY		37
#define ESO_BSDCOMPAT		38
#define ESO_PASSCRED		39
#define ESO_PEERCRED		40
#define ESO_SECURITY_AUTHENTICATION 41
#define ESO_SECURITY_ENCRYPTION_TRANSPORT 42
#define ESO_SECURITY_ENCRYPTION_NETWORK 43
#define ESO_BINDTODEVICE		44
#define ESO_ATTACH_FILTER		45
#define ESO_DETACH_FILTER		46
#define ESO_PEERNAME		47
#define ESO_TIMESTAMP		48
#define ESCM_TIMESTAMP		49
#define ESO_PEERSEC		50
#define ESO_PASSSEC		51
#define ESO_TIMESTAMPNS		52
#define ESCM_TIMESTAMPNS	53
#define ESO_MARK		54
#define ESO_TIMESTAMPING	55
#define ESCM_TIMESTAMPING	56
#define ESO_PROTOCOL		57
#define ESO_DOMAIN		58
#define ESO_RXQ_OVFL		59

int eusock_getsock_type(int x)
{
    switch (x)
    {
	case ESOCK_STREAM:
#ifdef SOCK_STREAM
		return SOCK_STREAM;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESOCK_DGRAM:
#ifdef SOCK_DGRAM
		return SOCK_DGRAM;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESOCK_RAW:
#ifdef SOCK_RAW
		return SOCK_RAW;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESOCK_RDM:
#ifdef SOCK_RDM
		return SOCK_RDM;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESOCK_SEQPACKET:
#ifdef SOCK_SEQPACKET
		return SOCK_SEQPACKET;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	default:
		return ESOCK_UNKNOWN_FLAG;
    }
}

int eusock_getfamily(int x)
{
    switch (x)
    {
	case EAF_UNSPEC:
#ifdef AF_UNSPEC
		return AF_UNSPEC;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case EAF_UNIX:
#ifdef AF_UNIX
		return AF_UNIX;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case EAF_INET:
#ifdef AF_INET
		return AF_INET;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case EAF_APPLETALK:
#ifdef AF_APPLETALK
		return AF_APPLETALK;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case EAF_INET6:
#ifdef AF_INET6
		return AF_INET6;
#elif defined(EWINDOWS)
		// hack as Watcom doesn't have AF_INET6 defined
		return 23;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case EAF_BTH:
#ifdef AF_BTH
		return AF_BTH;
#elif defined(EWINDOWS)
		// hack as Watcom doesn't have AF_BTH defined
		return 32;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	default:
		return ESOCK_UNKNOWN_FLAG;
    }
}

int eusock_getsock_option(int x)
{
    switch (x)
    {
	case ESOL_SOCKET:
#ifdef SOL_SOCKET
		return SOL_SOCKET;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DEBUG:
#ifdef SO_DEBUG
		return SO_DEBUG;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_ACCEPTCONN:
#ifdef SO_ACCEPTCONN
		return SO_ACCEPTCONN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_REUSEADDR:
#ifdef SO_REUSEADDR
		return SO_REUSEADDR;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_KEEPALIVE:
#ifdef SO_KEEPALIVE
		return SO_KEEPALIVE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DONTROUTE:
#ifdef SO_DONTROUTE
		return SO_DONTROUTE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_BROADCAST:
#ifdef SO_BROADCAST
		return SO_BROADCAST;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_LINGER:
#ifdef SO_LINGER
		return SO_LINGER;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SNDBUF:
#ifdef SO_SNDBUF
		return SO_SNDBUF;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_RCVBUF:
#ifdef SO_RCVBUF
		return SO_RCVBUF;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SNDLOWAT:
#ifdef SO_SNDLOWAT
		return SO_SNDLOWAT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_RCVLOWAT:
#ifdef SO_RCVLOWAT
		return SO_RCVLOWAT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SNDTIMEO:
#ifdef SO_SNDTIMEO
		return SO_SNDTIMEO;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_RCVTIMEO:
#ifdef SO_RCVTIMEO
		return SO_RCVTIMEO;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_ERROR:
#ifdef SO_ERROR
		return SO_ERROR;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_TYPE:
#ifdef SO_TYPE
		return SO_TYPE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_OOBINLINE:
#ifdef SO_OOBINLINE
		return SO_OOBINLINE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_USELOOPBACK:
#ifdef SO_USELOOPBACK
		return SO_USELOOPBACK;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DONTLINGER:
#ifdef SO_DONTLINGER
		return SO_DONTLINGER;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_REUSEPORT:
#ifdef SO_REUSEPORT
		return SO_REUSEPORT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_CONNDATA:
#ifdef SO_CONNDATA
		return SO_CONNDATA;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_CONNOPT:
#ifdef SO_CONNOPT
		return SO_CONNOPT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DISCDATA:
#ifdef SO_DISCDATA
		return SO_DISCDATA;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DISCOPT:
#ifdef SO_DISCOPT
		return SO_DISCOPT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_CONNDATALEN:
#ifdef SO_CONNDATALEN
		return SO_CONNDATALEN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_CONNOPTLEN:
#ifdef SO_CONNOPTLEN
		return SO_CONNOPTLEN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DISCDATALEN:
#ifdef SO_DISCDATALEN
		return SO_DISCDATALEN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DISCOPTLEN:
#ifdef SO_DISCOPTLEN
		return SO_DISCOPTLEN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_OPENTYPE:
#ifdef SO_OPENTYPE
		return SO_OPENTYPE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_MAXDG:
#ifdef SO_MAXDG
		return SO_MAXDG;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_MAXPATHDG:
#ifdef SO_MAXPATHDG
		return SO_MAXPATHDG;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SYNCHRONOUS_ALTERT:
#ifdef SO_SYNCHRONOUS_ALTERT
		return SO_SYNCHRONOUS_ALTERT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SYNCHRONOUS_NONALERT:
#ifdef SO_SYNCHRONOUS_NONALERT
		return SO_SYNCHRONOUS_NONALERT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SNDBUFFORCE:
#ifdef SO_SNDBUFFORCE
		return SO_SNDBUFFORCE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_RCVBUFFORCE:
#ifdef SO_RCVBUFFORCE
		return SO_RCVBUFFORCE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_NO_CHECK:
#ifdef SO_NO_CHECK
		return SO_NO_CHECK;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PRIORITY:
#ifdef SO_PRIORITY
		return SO_PRIORITY;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_BSDCOMPAT:
#ifdef SO_BSDCOMPAT
		return SO_BSDCOMPAT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PASSCRED:
#ifdef SO_PASSCRED
		return SO_PASSCRED;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PEERCRED:
#ifdef SO_PEERCRED
		return SO_PEERCRED;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SECURITY_AUTHENTICATION:
#ifdef SO_SECURITY_AUTHENTICATION
		return SO_SECURITY_AUTHENTICATION;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SECURITY_ENCRYPTION_TRANSPORT:
#ifdef SO_SECURITY_ENCRYPTION_TRANSPORT
		return SO_SECURITY_ENCRYPTION_TRANSPORT;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_SECURITY_ENCRYPTION_NETWORK:
#ifdef SO_SECURITY_ENCRYPTION_NETWORK
		return SO_SECURITY_ENCRYPTION_NETWORK;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_BINDTODEVICE:
#ifdef SO_BINDTODEVICE
		return SO_BINDTODEVICE;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_ATTACH_FILTER:
#ifdef SO_ATTACH_FILTER
		return SO_ATTACH_FILTER;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DETACH_FILTER:
#ifdef SO_DETACH_FILTER
		return SO_DETACH_FILTER;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PEERNAME:
#ifdef SO_PEERNAME
		return SO_PEERNAME;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_TIMESTAMP:
#ifdef SO_TIMESTAMP
		return SO_TIMESTAMP;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESCM_TIMESTAMP:
#ifdef SCM_TIMESTAMP
		return SCM_TIMESTAMP;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PEERSEC:
#ifdef SO_PEERSEC
		return SO_PEERSEC;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PASSSEC:
#ifdef SO_PASSSEC
		return SO_PASSSEC;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_TIMESTAMPNS:
#ifdef SO_TIMESTAMPNS
		return SO_TIMESTAMPNS;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESCM_TIMESTAMPNS:
#ifdef SCM_TIMESTAMPNS
		return SCM_TIMESTAMPNS;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_MARK:
#ifdef SO_MARK
		return SO_MARK;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_TIMESTAMPING:
#ifdef SO_TIMESTAMPING
		return SO_TIMESTAMPING;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESCM_TIMESTAMPING:
#ifdef SCM_TIMESTAMPING
		return SCM_TIMESTAMPING;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_PROTOCOL:
#ifdef SO_PROTOCOL
		return SO_PROTOCOL;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_DOMAIN:
#ifdef SO_DOMAIN
		return SO_DOMAIN;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	case ESO_RXQ_OVFL:
#ifdef SO_RXQ_OVFL
		return SO_RXQ_OVFL;
#else
		return ESOCK_UNDEFINED_VALUE;
#endif
	default:
		return ESOCK_UNKNOWN_FLAG;
    }
}

#ifdef EWINDOWS
    int eusock_wsastarted = 0;

    void eusock_wsastart()
    {
    	WORD wVersionRequested;
    	WSADATA wsaData;
    	int err;

    	wVersionRequested = MAKEWORD(2,2);
    	err = WSAStartup(wVersionRequested, &wsaData);
    	if (err != 0)
    	{
    		RTFatal("WSAStartup failed with error: %d", err);
    		return;
    	}

    	eusock_wsastarted = 1;
    }

    void eusock_wsacleanup()
    {
    	WSACleanup();
    }

    int eusock_geterror()
    {
		int code = WSAGetLastError();

		switch (WSAGetLastError()) {
			case WSANOTINITIALISED:
				return ERR_NOTINITIALISED;
			case WSAENETDOWN:
				return ERR_NETDOWN;
			case WSAEAFNOSUPPORT:
				return ERR_AFNOSUPPORT;
			case WSAEINPROGRESS:
				return ERR_INPROGRESS;
			case WSAEMFILE:
				return ERR_MFILE;
			case WSAENOBUFS:
				return ERR_NOBUFS;
			case WSAEPROTONOSUPPORT:
				return ERR_PROTONOSUPPORT;
			case WSAEPROTOTYPE:
				return ERR_PROTOTYPE;
			case WSAESOCKTNOSUPPORT:
				return ERR_SOCKTNOSUPPORT;
			case WSAENOTSOCK:
				return ERR_NOTSOCK;
			case WSAEINTR:
				return ERR_INTR;
			case WSAEWOULDBLOCK:
				return ERR_WOULDBLOCK;
			case WSAEINVAL:
				return ERR_INVAL;
			case WSAENOTCONN:
				return ERR_NOTCONN;
			case WSAEFAULT:
				return ERR_FAULT;
			case WSAENETRESET:
				return ERR_NETRESET;
			case WSAEOPNOTSUPP:
				return ERR_OPNOTSUPP;
			case WSAESHUTDOWN:
				return ERR_SHUTDOWN;
			case WSAEMSGSIZE:
				return ERR_MSGSIZE;
			case WSAEHOSTUNREACH:
				return ERR_HOSTUNREACH;
			case WSAECONNABORTED:
				return ERR_CONNABORTED;
			case WSAECONNRESET:
				return ERR_CONNRESET;
			case WSAETIMEDOUT:
				return ERR_TIMEDOUT;
			case WSAEADDRINUSE:
				return ERR_ADDRINUSE;
			case WSAEALREADY:
				return ERR_ALREADY;
			case WSAEADDRNOTAVAIL:
				return ERR_ADDRNOTAVAIL;
			case WSAECONNREFUSED:
				return ERR_CONNREFUSED;
			case WSAEISCONN:
				return ERR_ISCONN;
			case WSAENETUNREACH:
				return ERR_NETUNREACH;
			case WSAEDESTADDRREQ:
				return ERR_DESTADDRREQ;
			case WSAEACCES:
				return ERR_ACCESS;
			default:
				return -code;
		};
    }

    #define eusock_ensure_init() if (eusock_wsastarted == 0) eusock_wsastart();

#else // ifdef EWINDOWS
    #include <errno.h>
    int eusock_geterror()
    {
		switch (errno) {
			case ENOTDIR:
				return ERR_NOTDIR;
			case ENAMETOOLONG:
				return ERR_NAMETOOLONG;
			case ENOENT:
				return ERR_NOENT;
			case ELOOP:
				return ERR_LOOP;
			case ENETDOWN:
				return ERR_NETDOWN;
			case EAFNOSUPPORT:
				return ERR_AFNOSUPPORT;
			case EINPROGRESS:
				return ERR_INPROGRESS;
			case EMFILE:
				return ERR_MFILE;
			case ENFILE:
				return ERR_NFILE;
			case ENOBUFS:
				return ERR_NOBUFS;
			case EPROTONOSUPPORT:
				return ERR_PROTONOSUPPORT;
			case EPROTOTYPE:
				return ERR_PROTOTYPE;
			case ESOCKTNOSUPPORT:
				return ERR_SOCKTNOSUPPORT;
			case ENOTSOCK:
			case EBADF:
				return ERR_NOTSOCK;
			case EINTR:
				return ERR_INTR;
			case EWOULDBLOCK:
				return ERR_WOULDBLOCK;
			case EINVAL:
				return ERR_INVAL;
			case ENOTCONN:
				return ERR_NOTCONN;
			case EFAULT:
				return ERR_FAULT;
			case ENETRESET:
				return ERR_NETRESET;
			case EOPNOTSUPP:
				return ERR_OPNOTSUPP;
			case ESHUTDOWN:
				return ERR_SHUTDOWN;
			case EMSGSIZE:
				return ERR_MSGSIZE;
			case EHOSTUNREACH:
				return ERR_HOSTUNREACH;
			case ECONNABORTED:
				return ERR_CONNABORTED;
			case ECONNRESET:
				return ERR_CONNRESET;
			case ETIMEDOUT:
				return ERR_TIMEDOUT;
			case EADDRINUSE:
				return ERR_ADDRINUSE;
			case EALREADY:
				return ERR_ALREADY;
			case EADDRNOTAVAIL:
				return ERR_ADDRNOTAVAIL;
			case ECONNREFUSED:
				return ERR_CONNREFUSED;
			case EISCONN:
				return ERR_ISCONN;
			case ENETUNREACH:
				return ERR_NETUNREACH;
			case EDESTADDRREQ:
				return ERR_DESTADDRREQ;
#if 0
			// EAGAIN is the same as EWOULDBLOCK on Linux
			case EAGAIN:
				return ERR_AGAIN;
#endif /* if 0 */
			case EIO:
				return ERR_IO;
			case EROFS:
				return ERR_ROFS;
			case EISDIR:
				return ERR_ISDIR;
			default:
				if (errno < 0)
					return errno;
				return -errno;
		};
    }

    #define eusock_ensure_init()
#endif // ifdef EWINDOWS else

/* ============================================================================
 *
 * Information functions
 *
 * ========================================================================== */

/*
 * eusock_info(type)
 */

object eusock_info(object x)
{
	s1_ptr result_s;
	if (IS_ATOM_INT(x)) {
		if (x == ESOCK_TYPE_AF) {
			result_s = NewS1(6);
			result_s->base[EAF_UNSPEC] = eusock_getfamily(EAF_UNSPEC);
			result_s->base[EAF_UNIX] = eusock_getfamily(EAF_UNIX);
			result_s->base[EAF_INET] = eusock_getfamily(EAF_INET);
			result_s->base[EAF_INET6] = eusock_getfamily(EAF_INET6);
			result_s->base[EAF_APPLETALK] = eusock_getfamily(EAF_APPLETALK);
			result_s->base[EAF_BTH] = eusock_getfamily(EAF_BTH);
		} else if (x == ESOCK_TYPE_TYPE) {
			result_s = NewS1(5);
			result_s->base[ESOCK_STREAM] = eusock_getsock_type(ESOCK_STREAM);
			result_s->base[ESOCK_DGRAM] = eusock_getsock_type(ESOCK_DGRAM);
			result_s->base[ESOCK_RAW] = eusock_getsock_type(ESOCK_RAW);
			result_s->base[ESOCK_RDM] = eusock_getsock_type(ESOCK_RDM);
			result_s->base[ESOCK_SEQPACKET] = eusock_getsock_type(ESOCK_SEQPACKET);
		} else if (x == ESOCK_TYPE_OPTION) {
			result_s = NewS1(59);
			result_s->base[ESOL_SOCKET] = eusock_getsock_option(ESOL_SOCKET);
			result_s->base[ESO_DEBUG] = eusock_getsock_option(ESO_DEBUG);
			result_s->base[ESO_ACCEPTCONN] = eusock_getsock_option(ESO_ACCEPTCONN);
			result_s->base[ESO_REUSEADDR] = eusock_getsock_option(ESO_REUSEADDR);
			result_s->base[ESO_KEEPALIVE] = eusock_getsock_option(ESO_KEEPALIVE);
			result_s->base[ESO_DONTROUTE] = eusock_getsock_option(ESO_DONTROUTE);
			result_s->base[ESO_BROADCAST] = eusock_getsock_option(ESO_BROADCAST);
			result_s->base[ESO_LINGER] = eusock_getsock_option(ESO_LINGER);
			result_s->base[ESO_SNDBUF] = eusock_getsock_option(ESO_SNDBUF);
			result_s->base[ESO_RCVBUF] = eusock_getsock_option(ESO_RCVBUF);
			result_s->base[ESO_SNDLOWAT] = eusock_getsock_option(ESO_SNDLOWAT);
			result_s->base[ESO_RCVLOWAT] = eusock_getsock_option(ESO_RCVLOWAT);
			result_s->base[ESO_SNDTIMEO] = eusock_getsock_option(ESO_SNDTIMEO);
			result_s->base[ESO_RCVTIMEO] = eusock_getsock_option(ESO_RCVTIMEO);
			result_s->base[ESO_ERROR] = eusock_getsock_option(ESO_ERROR);
			result_s->base[ESO_TYPE] = eusock_getsock_option(ESO_TYPE);
			result_s->base[ESO_OOBINLINE] = eusock_getsock_option(ESO_OOBINLINE);
			result_s->base[ESO_USELOOPBACK] = eusock_getsock_option(ESO_USELOOPBACK);
			result_s->base[ESO_DONTLINGER] = eusock_getsock_option(ESO_DONTLINGER);
			result_s->base[ESO_REUSEPORT] = eusock_getsock_option(ESO_REUSEPORT);
			result_s->base[ESO_CONNDATA] = eusock_getsock_option(ESO_CONNDATA);
			result_s->base[ESO_CONNOPT] = eusock_getsock_option(ESO_CONNOPT);
			result_s->base[ESO_DISCDATA] = eusock_getsock_option(ESO_DISCDATA);
			result_s->base[ESO_DISCOPT] = eusock_getsock_option(ESO_DISCOPT);
			result_s->base[ESO_CONNDATALEN] = eusock_getsock_option(ESO_CONNDATALEN);
			result_s->base[ESO_CONNOPTLEN] = eusock_getsock_option(ESO_CONNOPTLEN);
			result_s->base[ESO_DISCDATALEN] = eusock_getsock_option(ESO_DISCDATALEN);
			result_s->base[ESO_DISCOPTLEN] = eusock_getsock_option(ESO_DISCOPTLEN);
			result_s->base[ESO_OPENTYPE] = eusock_getsock_option(ESO_OPENTYPE);
			result_s->base[ESO_MAXDG] = eusock_getsock_option(ESO_MAXDG);
			result_s->base[ESO_MAXPATHDG] = eusock_getsock_option(ESO_MAXPATHDG);
			result_s->base[ESO_SYNCHRONOUS_ALTERT] = eusock_getsock_option(ESO_SYNCHRONOUS_ALTERT);
			result_s->base[ESO_SYNCHRONOUS_NONALERT] = eusock_getsock_option(ESO_SYNCHRONOUS_NONALERT);
			result_s->base[ESO_SNDBUFFORCE] = eusock_getsock_option(ESO_SNDBUFFORCE);
			result_s->base[ESO_RCVBUFFORCE] = eusock_getsock_option(ESO_RCVBUFFORCE);
			result_s->base[ESO_NO_CHECK] = eusock_getsock_option(ESO_NO_CHECK);
			result_s->base[ESO_PRIORITY] = eusock_getsock_option(ESO_PRIORITY);
			result_s->base[ESO_BSDCOMPAT] = eusock_getsock_option(ESO_BSDCOMPAT);
			result_s->base[ESO_PASSCRED] = eusock_getsock_option(ESO_PASSCRED);
			result_s->base[ESO_PEERCRED] = eusock_getsock_option(ESO_PEERCRED);
			result_s->base[ESO_SECURITY_AUTHENTICATION] = eusock_getsock_option(ESO_SECURITY_AUTHENTICATION);
			result_s->base[ESO_SECURITY_ENCRYPTION_TRANSPORT] = eusock_getsock_option(ESO_SECURITY_ENCRYPTION_TRANSPORT);
			result_s->base[ESO_SECURITY_ENCRYPTION_NETWORK] = eusock_getsock_option(ESO_SECURITY_ENCRYPTION_NETWORK);
			result_s->base[ESO_BINDTODEVICE] = eusock_getsock_option(ESO_BINDTODEVICE);
			result_s->base[ESO_ATTACH_FILTER] = eusock_getsock_option(ESO_ATTACH_FILTER);
			result_s->base[ESO_DETACH_FILTER] = eusock_getsock_option(ESO_DETACH_FILTER);
			result_s->base[ESO_PEERNAME] = eusock_getsock_option(ESO_PEERNAME);
			result_s->base[ESO_TIMESTAMP] = eusock_getsock_option(ESO_TIMESTAMP);
			result_s->base[ESCM_TIMESTAMP] = eusock_getsock_option(ESCM_TIMESTAMP);
			result_s->base[ESO_PEERSEC] = eusock_getsock_option(ESO_PEERSEC);
			result_s->base[ESO_PASSSEC] = eusock_getsock_option(ESO_PASSSEC);
			result_s->base[ESO_TIMESTAMPNS] = eusock_getsock_option(ESO_TIMESTAMPNS);
			result_s->base[ESCM_TIMESTAMPNS] = eusock_getsock_option(ESCM_TIMESTAMPNS);
			result_s->base[ESO_MARK] = eusock_getsock_option(ESO_MARK);
			result_s->base[ESO_TIMESTAMPING] = eusock_getsock_option(ESO_TIMESTAMPING);
			result_s->base[ESCM_TIMESTAMPING] = eusock_getsock_option(ESCM_TIMESTAMPING);
			result_s->base[ESO_PROTOCOL] = eusock_getsock_option(ESO_PROTOCOL);
			result_s->base[ESO_DOMAIN] = eusock_getsock_option(ESO_DOMAIN);
			result_s->base[ESO_RXQ_OVFL] = eusock_getsock_option(ESO_RXQ_OVFL);
		} else {
			return ATOM_M1;
		}
		return MAKE_SEQ(result_s);
	} else {
		return ATOM_M1;
	}
}

/*
 * getservbyname(name, proto)
 */

object eusock_getservbyname(object x)
{
	char *name, *proto;
	s1_ptr name_s, proto_s, result_s;

	struct servent *ent;

	eusock_ensure_init();

	if (!IS_SEQUENCE(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to service_by_name must be a sequence");

	name_s = SEQ_PTR(SEQ_PTR(x)->base[1]);
	name   = EMalloc(name_s->length+1);
	MakeCString(name, SEQ_PTR(x)->base[1], name_s->length+1 );

	if (IS_SEQUENCE(SEQ_PTR(x)->base[2]))
	{
		proto_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
		proto = EMalloc(proto_s->length+1);
		MakeCString(proto, SEQ_PTR(x)->base[2], proto_s->length+1);
	}
	else
	{
		proto = 0;
	}

	// ent is static data, do not release
	ent = getservbyname(name, proto);

	EFree(name);
	if (proto != 0)
	{
		EFree(proto);
	}

	if (ent == NULL)
	{
		return eusock_geterror();
	}

	result_s = NewS1(3); // official name, port
	result_s->base[1] = NewString(ent->s_name);
	result_s->base[2] = NewString(ent->s_proto);
	result_s->base[3] = htons(ent->s_port);

	return MAKE_SEQ(result_s);
}

/*
 * getservbyport(port, proto)
 */

object eusock_getservbyport(object x)
{
	char *proto;
	int port;
	s1_ptr proto_s, result_s;

	struct servent *ent;

	eusock_ensure_init();

	if (!IS_ATOM_INT(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to service_by_port must be an integer");

	port = SEQ_PTR(x)->base[1];

	if (IS_SEQUENCE(SEQ_PTR(SEQ_PTR(x)->base[2])))
	{
		proto_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
		proto = EMalloc(proto_s->length+1);
		MakeCString(proto, SEQ_PTR(x)->base[2], proto_s->length+1);
	}
	else
	{
		proto = 0;
	}

	// ent is static data, do not release
	ent = getservbyport(ntohs(port), proto);

	if (proto != 0)
	{
		EFree(proto);
	}

	if (ent == NULL)
	{
		return eusock_geterror();
	}

	result_s = NewS1(3); // official name, port
	result_s->base[1] = NewString(ent->s_name);
	result_s->base[2] = NewString(ent->s_proto);
	result_s->base[3] = htons(ent->s_port);

	return MAKE_SEQ(result_s);
}

object eusock_build_hostent(struct hostent *ent)
{
	char **aliases;
	int count;
	s1_ptr aliases_s, ips_s, result_s;

	struct in_addr addr;

	if (ent == NULL)
	{
		return eusock_geterror();
	}

	count = 0;
	for (aliases = ent->h_aliases; *aliases != 0; aliases++)
	{
		count += 1;
	}

	aliases_s = NewS1(count);
	count = 1;
	aliases = ent->h_aliases;
	while (*aliases != 0) {
		aliases_s->base[count] = NewString(*aliases);

		aliases++;
		count += 1;
	}

	count = 0;
	while (ent->h_addr_list[count] != 0)
	{
		count += 1;
	}

	ips_s = NewS1(count);
	count = 0;
	while (ent->h_addr_list[count] != 0)
	{
		addr.s_addr = * (u_long *) ent->h_addr_list[count];
		ips_s->base[count+1] = NewString(inet_ntoa(addr));
		count += 1;
	}

	result_s = NewS1(4); // official name, alias names, ip addresses, address type
	result_s->base[1] = NewString(ent->h_name);
	result_s->base[2] = MAKE_SEQ(aliases_s);
	result_s->base[3] = MAKE_SEQ(ips_s);
	result_s->base[4] = ent->h_addrtype;

	return MAKE_SEQ(result_s);
}

/*
 * gethostbyname(name)
 */

object eusock_gethostbyname(object x)
{
	char *name;

	s1_ptr name_s;

	struct hostent *ent;

	eusock_ensure_init();

	if (!IS_SEQUENCE(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to host_by_name must be a sequence");

	name_s = SEQ_PTR(SEQ_PTR(x)->base[1]);
	name   = EMalloc(name_s->length+1);
	MakeCString(name, SEQ_PTR(x)->base[1], name_s->length+1 );

	// ent is static data, do not release
	ent = gethostbyname(name);

	EFree(name);

	return eusock_build_hostent(ent);
}

/*
 * gethostbyaddr(addr)
 */

object eusock_gethostbyaddr(object x)
{
	char *address;
	s1_ptr address_s;

	struct hostent *ent;
	struct in_addr addr;

	eusock_ensure_init();

	if (!IS_SEQUENCE(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to host_by_addr must be a sequence");

	address_s = SEQ_PTR(SEQ_PTR(x)->base[1]);
	address   = EMalloc(address_s->length+1);
	MakeCString(address, SEQ_PTR(x)->base[1], address_s->length+1 );

	addr.s_addr = inet_addr(address);
	if (addr.s_addr == INADDR_NONE)
	{
		return ERR_FAULT;
	}

	// ent is static data, do not release
	ent = gethostbyaddr((char *) &addr, 4, AF_INET);

	EFree(address);

	return eusock_build_hostent(ent);
}

/* ============================================================================
 *
 * Error Information
 *
 * ========================================================================= */

object eusock_error_code()
{
	return eusock_geterror();
}

/* ============================================================================
 *
 * Shared Client/Server functions
 *
 * ========================================================================== */

/*
 * socket(af, type, protocol)
 *
 * return { socket, sockaddr_in }
 */

object eusock_socket(object x)
{
	int af, type, protocol;
	SOCKET sock;
	struct sockaddr_in *addr;

	s1_ptr result_p;

	eusock_ensure_init();

	if (!IS_ATOM_INT(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to socket must be an integer");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to socket must be an integer");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to socket must be an integer");

	af       = SEQ_PTR(x)->base[1];
	type     = SEQ_PTR(x)->base[2];
	protocol = SEQ_PTR(x)->base[3];

	sock = socket(af, type, protocol);
	if (sock == INVALID_SOCKET)
	{
		return eusock_geterror();
	}

	addr = (struct sockaddr_in *)EMalloc((unsigned long)sizeof(struct sockaddr_in));
	addr->sin_family = af;
	addr->sin_port   = 0;

	result_p = NewS1(2);
	result_p->base[1] = sock;

	if ((unsigned) addr > (unsigned)MAXINT)
		result_p->base[2] = NewDouble((double)(unsigned long) addr);
	else
		result_p->base[2] = (object)addr;

	return MAKE_SEQ(result_p);
}

/*
 * close(sock)
 */

object eusock_close(object x)
{
	SOCKET s;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to close must be a socket");

	s = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];

	if (closesocket(s) == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return ERR_OK;
}

/*
 * shutdown(sock, how)
 */

object eusock_shutdown(object x)
{
	SOCKET s;
	int how;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to shutdown must be a socket");

	s = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	how = SEQ_PTR(x)->base[2];

	if (shutdown(s, how) == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return ERR_OK;
}

/*
 * connect(sock, address, port)
 */

object eusock_connect(object x)
{
	SOCKET s;
	struct sockaddr_in *addr;
	int result;

	s1_ptr address_s;
	char *address;

	eusock_ensure_init();

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to connect must be a socket");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to connect must be a sequence");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to connect must be an integer");

	s    = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	addr = (struct sockaddr_in *)SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKADDR];

	addr->sin_port = htons(SEQ_PTR(x)->base[3]);

	address_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
	address   = EMalloc(address_s->length+1);
	MakeCString(address, SEQ_PTR(x)->base[2], address_s->length+1);

	addr->sin_addr.s_addr = inet_addr(address);
	if (addr->sin_addr.s_addr == INADDR_NONE)
	{
		return ERR_FAULT;
	}

	result = connect(s, (struct sockaddr const *)addr, sizeof(SOCKADDR));

	EFree(address);

	if (result == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return ERR_OK;
}

/*
 * select({ socket, ... }, timeout)
 */

object eusock_select(object x)
{
	SOCKET tmp_socket;
	int i, timeout_microsecs, timeout_sec, result, max_sock;
	fd_set readable, writable, errd;
	struct timeval tv_timeout;

	s1_ptr socks_pread, socks_pwrite, socks_perr, socks_pall,
	result_p, tmp_sp;

	if (!IS_SEQUENCE(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to select must be a sequence of sockets");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to select must be a sequence of sockets");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to select must be a sequence of sockets");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[4]))
		RTFatal("fourth argument to select must be a sequence of sockets");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[5]))
		RTFatal("fiftth argument to select must be an integer");

	if (!IS_ATOM_INT(SEQ_PTR(x)->base[6]))
		RTFatal("sixth argument to select must be an integer");

	socks_pread = SEQ_PTR(SEQ_PTR(x)->base[1]);
	socks_pwrite = SEQ_PTR(SEQ_PTR(x)->base[2]);
	socks_perr = SEQ_PTR(SEQ_PTR(x)->base[3]);
	socks_pall = SEQ_PTR(SEQ_PTR(x)->base[4]);
	timeout_microsecs = SEQ_PTR(x)->base[5];
	timeout_sec = SEQ_PTR(x)->base[6];
	max_sock = 0;

	// prepare our fd_set
	FD_ZERO(&readable);
	FD_ZERO(&writable);
	FD_ZERO(&errd);

	for (i=1; i <= socks_pread->length; i++) {
		if (!IS_SOCKET(socks_pread->base[i]))
			RTFatal("first argument to select must be a sequence of sockets");
		tmp_socket = SEQ_PTR(socks_pread->base[i])->base[SOCK_SOCKET];

		FD_SET(tmp_socket, &readable);

		max_sock = (max_sock > tmp_socket) ? max_sock : tmp_socket;
	}

	for (i=1; i <= socks_pwrite->length; i++) {
		if (!IS_SOCKET(socks_pwrite->base[i]))
			RTFatal("first argument to select must be a sequence of sockets");
		tmp_socket = SEQ_PTR(socks_pwrite->base[i])->base[SOCK_SOCKET];

		FD_SET(tmp_socket, &writable);

		max_sock = (max_sock > tmp_socket) ? max_sock : tmp_socket;
	}

	for (i=1; i <= socks_perr->length; i++) {
		if (!IS_SOCKET(socks_perr->base[i]))
			RTFatal("first argument to select must be a sequence of sockets");
		tmp_socket = SEQ_PTR(socks_perr->base[i])->base[SOCK_SOCKET];

		FD_SET(tmp_socket, &errd);

		max_sock = (max_sock > tmp_socket) ? max_sock : tmp_socket;
	}

	tv_timeout.tv_sec = timeout_sec;
	tv_timeout.tv_usec = timeout_microsecs;

	result = select(max_sock + 1, &readable, &writable, &errd, &tv_timeout);

	if (result == -1) {
		return eusock_geterror();
	}

	result_p = NewS1(socks_pall->length);
	for (i=1; i <= socks_pall->length; i++) {
		tmp_socket = SEQ_PTR(socks_pall->base[i])->base[SOCK_SOCKET];

		RefDS(socks_pall->base[i]);

		tmp_sp = NewS1(4);
		tmp_sp->base[1] = socks_pall->base[i];
		tmp_sp->base[2] = FD_ISSET(tmp_socket, &readable) != 0;
		tmp_sp->base[3] = FD_ISSET(tmp_socket, &writable) != 0;
		tmp_sp->base[4] = FD_ISSET(tmp_socket, &errd) != 0;

		result_p->base[i] = MAKE_SEQ(tmp_sp);
	}

	return MAKE_SEQ(result_p);
}


/*
 * send(sock, buf, flags)
 */

object eusock_send(object x)
{
	SOCKET s;
	int flags, result;
	char *buf;

	s1_ptr buf_s;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to send must be a socket");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to send must be a sequence");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to send must be an integer");

	s     = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	buf_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
	buf   = EMalloc(buf_s->length+1);
	MakeCString(buf, SEQ_PTR(x)->base[2], buf_s->length + 1);
	flags = SEQ_PTR(x)->base[3];

	result = send(s, buf, buf_s->length, flags);

	EFree(buf);

	if (result == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return result;
}

/*
 * recv(sock, flags)
 */

object eusock_recv(object x)
{
	SOCKET s;
	int flags, result;
	char buf[BUFF_SIZE];

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to recv must be a socket");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to recv must be an integer");

	s     = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	flags = SEQ_PTR(x)->base[2];

	result = recv(s, buf, BUFF_SIZE - 1, flags);

	if (result > 0) {
		return NewSequence(buf, result);
	} else if (result == 0) {
		return ATOM_0;
	} else {
		return eusock_geterror();
	}
}

/* ============================================================================
 *
 * UDP functions
 *
 * ========================================================================== */

object eusock_sendto(object x)
{
	SOCKET s;
	struct sockaddr_in addr;
	int flags, port, result;

	s1_ptr buf_s;
    s1_ptr ip_s;
	char *buf, *ip;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to sendto must be a socket");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to sendto must be a sequence");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to sendto must be an integer");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[4]))
		RTFatal("fourth argument to sendto must be a sequence");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[5]))
		RTFatal("fifth argument to sendto must be an integer");

	s     = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	flags = SEQ_PTR(x)->base[3];
    ip_s  = SEQ_PTR(SEQ_PTR(x)->base[4]);
    port  = SEQ_PTR(x)->base[5];

	buf_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
	buf   = EMalloc(buf_s->length+1);
	MakeCString(buf, SEQ_PTR(x)->base[2], buf_s->length+1);
	ip = EMalloc(ip_s->length + 1);
    MakeCString(ip, SEQ_PTR(x)->base[4], ip_s->length+1);

	addr.sin_family = AF_INET;
	addr.sin_port   = htons(port);
    addr.sin_addr.s_addr = inet_addr(ip);

	result = sendto(s, buf, buf_s->length, flags, (struct sockaddr*) &addr, sizeof(addr));

	EFree(buf);
    EFree(ip);

	if (result == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return result;
}

object eusock_recvfrom(object x)
{
	SOCKET s;
	struct sockaddr_in addr;
	int flags, result;
	socklen_t addr_size;
	char buf[BUFF_SIZE];

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to recvfrom must be a socket");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to recvfrom must be an integer");

	s     = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	flags = SEQ_PTR(x)->base[2];
    addr_size = sizeof(addr);

	result = recvfrom(s, buf, BUFF_SIZE - 1, flags, (struct sockaddr *) &addr, &addr_size);

	if (result > 0) {
        s1_ptr r;
		buf[result] = 0;

        r = NewS1(3);
        r->base[1] = NewString(inet_ntoa(addr.sin_addr));
        r->base[2] = addr.sin_port;
        r->base[3] = NewSequence(buf, result);

        return MAKE_SEQ(r);
	} else if (result == 0) {
		return ATOM_0;
	} else {
		return eusock_geterror();
	}
}

/* ============================================================================
 *
 * Server functions
 *
 * ========================================================================== */

/*
 * bind(socket, address, port)
 */

object eusock_bind(object x)
{
	SOCKET s;
	s1_ptr address_s;
	char *address;
	int port, result;

	struct sockaddr_in *service;

	eusock_ensure_init();

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to bind must be a socket");
	if (!IS_SEQUENCE(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to bind must be a sequence");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to bind must be an integer");

	s       = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	service = (struct sockaddr_in *)SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKADDR];
	port    = SEQ_PTR(x)->base[3];

	address_s = SEQ_PTR(SEQ_PTR(x)->base[2]);
	address   = EMalloc(address_s->length+1);
	MakeCString(address, SEQ_PTR(x)->base[2], address_s->length+1);

	service->sin_addr.s_addr = inet_addr(address);
	service->sin_port        = htons(port);

	result = bind(s, (struct sockaddr const *)service, sizeof(SOCKADDR));

	EFree(address);

	if (result == SOCKET_ERROR)
	{
	  return eusock_geterror();
	}

	return ERR_OK;
}

/*
 * listen(socket, backlog)
 */

object eusock_listen(object x)
{
	SOCKET s;
	int backlog;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to listen must be a socket");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to listen must be an integer");

	s       = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	backlog = SEQ_PTR(x)->base[2];

	if (listen(s, backlog) == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return ERR_OK;
}

/*
 * accept(socket)
 */

object eusock_accept(object x)
{
	SOCKET server, client;
	struct sockaddr_in addr;
	socklen_t addr_len;

	s1_ptr client_seq, client_sock_p;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to accept must be a socket");

	server = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];

	addr_len = sizeof(addr);
	client   = accept(server, (struct sockaddr *)&addr, &addr_len);

	if (client == INVALID_SOCKET)
	{
		return eusock_geterror();
	}

	client_sock_p = NewS1(2);
	client_sock_p->base[1] = client;
	client_sock_p->base[2] = 0;

	client_seq = NewS1(2);
	client_seq->base[1] = MAKE_SEQ(client_sock_p);
	client_seq->base[2] = NewString( inet_ntoa( addr.sin_addr ) );

	return MAKE_SEQ(client_seq);
}

/*
 * getsockopt(socket, level, optname)
 */

object eusock_getsockopt(object x)
{
	SOCKET s;
	int level, optname, optval;
	socklen_t optlen;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to get_option must be a socket");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to get_option must be an integer");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to get_option must be an integer");

	optlen  = sizeof(int);
	s       = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	level   = SEQ_PTR(x)->base[2];
	optname = SEQ_PTR(x)->base[3];

	if (getsockopt(s, level, optname, (char *) &optval, &optlen) == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return optval;
}

/*
 * setsockopt(socket, level, optname, value)
 */

object eusock_setsockopt(object x)
{
	SOCKET s;
	int level, optname, optlen, optval;

	if (!IS_SOCKET(SEQ_PTR(x)->base[1]))
		RTFatal("first argument to set_option must be a socket");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[2]))
		RTFatal("second argument to set_option must be an integer");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[3]))
		RTFatal("third argument to set_option must be an integer");
	if (!IS_ATOM_INT(SEQ_PTR(x)->base[4]))
		RTFatal("forth argument to set_option must be an integer");

	optlen  = sizeof(int);
	s       = SEQ_PTR(SEQ_PTR(x)->base[1])->base[SOCK_SOCKET];
	level   = SEQ_PTR(x)->base[2];
	optname = SEQ_PTR(x)->base[3];
	optval  = SEQ_PTR(x)->base[4];

	if (setsockopt(s, level, optname, (char *) &optval, optlen) == SOCKET_ERROR)
	{
		return eusock_geterror();
	}

	return optval;
}

