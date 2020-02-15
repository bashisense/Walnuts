
CC = gcc

INCLUDE = -I/usr/local/include/luajit-2.1
CFLAGS = -O2 $(INCLUDE)


libs = -levent -lluajit-5.1 -pthread

LDFLAGS = -L../lib $(libs)


objs = main.o

TARGET = Walnuts

$(TARGET) : $(objs)
	$(CC) -o $@ $(objs) $(LDFLAGS)
	cp $(TARGET) ../bin/

%.o : %.c 
	$(CC) -c -o $@  $(CFLAGS) $<

clean :
	rm -f $(objs) ../bin/$(TARGET)