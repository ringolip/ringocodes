#include <stdio.h>
// 打印从1到N的全部正整数
// 使用递归方法
void PrintN(int N)
{
    if(N>0){
        PrintN(N-1);
        printf("%d\n", N);
    }
}

int main()
{
    // 读取整数N,并调用PrintN函数
    int N;
    scanf("%d", &N);
    PrintN(N);
    return 0;
}