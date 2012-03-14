#include "wol.h"

#define BUFMAX	1024
#define MACLEN	6

int host2addr(char *name, struct in_addr *addrp, unsigned char *familyp) {
    struct hostent *hp;

    if ((hp=gethostbyname(name))) {
        bcopy(hp->h_addr, (char *)addrp, hp->h_length);
        if (familyp) *familyp = hp->h_addrtype;
    } else if ((addrp->s_addr=inet_addr(name)) != -1) {
        if (familyp) *familyp = AF_INET;
    } else {
        fprintf(stderr,"Unknown host : %s\n", name);

        return 1;
    }

    return 0;
}

int hex(unsigned char c) {
    if ('0' <= c && c <= '9') return c - '0';
    if ('a' <= c && c <= 'f') return c - 'a' + 10;
    if ('A' <= c && c <= 'F') return c - 'A' + 10;

    return -1;
}

int hex2(unsigned char *p) {
    int i;
    unsigned char c;

    i = hex(*p++);
    if (i < 0) return i;

    c = (i << 4);
    i = hex(*p);
    if (i < 0) return i;

    return c | i;
}

int send_wol_packet(unsigned char *broadcast_addr, unsigned char *mac_addr)
{
    int sd;
    int optval;
    char unsigned buf[BUFMAX];
    int len;
    struct sockaddr_in sin;
    unsigned char mac[MACLEN];
    unsigned char *p;
    int i, j;

    bzero((char *)&sin,sizeof(sin)); /* clear sin struct */
    sin.sin_family = AF_INET;
    host2addr(broadcast_addr,&sin.sin_addr,&sin.sin_family);	/* host */
    sin.sin_port = htons(9);	/* port */
    if ((sd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP)) < 0) {
        fprintf(stderr,"Can't get socket.\n");
        return 1;
    }
    optval = 1;
    if (setsockopt(sd,SOL_SOCKET,SO_BROADCAST,&optval,sizeof(optval)) < 0) {
        fprintf(stderr,"Can't set sockopt (%d).\n",errno);
        return 1;
    }
    p = mac_addr;
    j = hex2(p);
    if (j < 0) {
    MACerror:
        fprintf(stderr,"Illegal MAC address: %s\n",mac_addr);
        return 1;
    }
    mac[0] = j;
    p += 2;
    for (i=1; i < MACLEN; i++) {
        if (*p++ != ':') goto MACerror;
        j = hex2(p);
        if (j < 0) goto MACerror;
        mac[i] = j;
        p += 2;
    }
    p = buf;
    for (i=0; i < 6; i++) {	/* 6 bytes of FFhex */
        *p++ = 0xFF;
    }
    for (i=0; i < 16; i++) {	/* MAC addresses repeated 16 times */
        for (j=0; j < MACLEN; j++) {
            *p++ = mac[j];
        }
    }
    len = p - buf;

    if (sendto(sd,buf,len,0,
               (struct sockaddr*)&sin,sizeof(sin)) != len) {
        fprintf(stderr,"Sendto failed (%d).\n",errno);
    }
    
    return 0;
}
