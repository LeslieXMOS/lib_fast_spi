THREAD_DIV = 5
clk_cnt = 0
thread_instruct_cnt = 0
out_shift_cnt = 32
out_transfer_full = 0
next_cnt = [6,6,7,6,7,6,6,7,6,7]
i = 0
while True:
    if clk_cnt % 5 == 0:
        if thread_instruct_cnt % next_cnt[i%10] == 0:
            i += 1
            if out_transfer_full:
                print(f"blocking {clk_cnt} {thread_instruct_cnt}")
                assert False
            out_transfer_full = 1
        thread_instruct_cnt += 1
        pass
    else:
        pass
    clk_cnt += 1
    out_shift_cnt -= 1
    if out_shift_cnt == 0:
        if (out_transfer_full == 0):
            print(f"failed {clk_cnt} {thread_instruct_cnt}")
            assert False
        out_transfer_full = 0
        out_shift_cnt = 32