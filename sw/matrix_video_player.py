#!/bin/python3.7
import socket
import numpy as np
import mss, time

'''
Usage: python3.7 matrix_video_player.py
'''

UDP_IP = '192.168.178.50'
UDP_PORT = 26177

input_size = 1280    # input square size
offset_x = 310      # left offset
offset_y = 210      # top offset

monitor = {'top': offset_y, 'left': offset_x, 'width': input_size, 'height': int(input_size/2)}

num_rows = 64
num_cols = 128
bin_size_w = int(monitor["width"] / num_cols)
bin_size_h = int(monitor["height"] / num_rows)
fbuf = np.zeros((num_cols), dtype='i4')

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

while(1):
    sct = mss.mss()
    cast = np.array(sct.grab(monitor), dtype='u4').reshape((num_rows, bin_size_h, num_cols, bin_size_w,4)).max(3).max(1)
    sct.close()
    cast.astype(int)
    start = time.time()
    totalBytes = 0
    for y in range(num_rows):
        for x in range(num_cols):
            addr = ((y & 0x7F) << 7) | (x & 0x7F);

            r = cast[y][x][2].item()
            g = cast[y][x][1].item()
            b = cast[y][x][0].item()

            fbuf[x] = socket.htonl((addr << 18)     | (((int(r))&0xFC) << 10)
                                                    | (((int(g))&0xFC) << 4)
                                                    | (((int(b))&0xFC) >> 2))

        s.sendto(fbuf.tobytes(), (UDP_IP, UDP_PORT))
        totalBytes += len(fbuf.tobytes())
    delta = (time.time() - start) * 1000
    print("Took %f ms to send %d bytes" % (delta, totalBytes))
exit()
