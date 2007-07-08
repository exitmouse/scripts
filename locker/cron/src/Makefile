# Makefile for dillon's cron and crontab
#

DESTDIR ?= /usr/local
CC  = gcc
CFLAGS = -O2 -Wall -Wstrict-prototypes
LIB = 
D_SRCS = cronload.real.c subs.c
D_OBJS = cronload.real.o subs.o

all:	cronload.real

cronload.real:  ${D_OBJS}
	${CC} ${CFLAGS} -o cronload.real ${D_OBJS}
	strip cronload.real

clean:  cleano
	rm -f cronload.real

cleano:
	rm -f *.o

install:
	install -o root -g wheel -m 4755 cronload.real ${DESTDIR}/bin/cronload.real
#	install -o root -g wheel -m 0644 crontab.1 ${DESTDIR}/man/man1/crontab.1


