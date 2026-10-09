#include <sys/shm.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    int id=shmget(IPC_PRIVATE,8192,0600);if(id<0)return 91;
    char *a=shmat(id,0,0), *b=shmat(id,0,0);if(a==(void*)-1||b==(void*)-1||a==b)return 92;
    strcpy(a+4090,"shared across pages");if(strcmp(b+4090,"shared across pages"))return 93;
    struct shmid_ds info;if(shmctl(id,IPC_STAT,&info)||info.shm_segsz!=8192||info.shm_nattch!=2)return 94;
    if(shmctl(id,IPC_RMID,0)||shmdt(a)||strcmp(b+4090,"shared across pages"))return 95;
    if(shmdt(b)||shmctl(id,IPC_STAT,&info)!=-1)return 96;
    puts("SHM PASS: aliases, cross-page data, stats, deferred deletion");return 0;
}
