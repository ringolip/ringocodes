# include <stdio.h>

void PrintN(int N) 
{   
    // 传入一个正整数参数后，顺序打印从1到N的全部正整数
    // 使用循环语句
	int i;
    for(i=1; i<=N; i++)
        printf("%d\n", i);
    return;
}

int main()
{
    // 读入整数N，并调用PrintN函数
    int N;
    scanf("%d", &N);
    PrintN(N);
    return 0;
}
