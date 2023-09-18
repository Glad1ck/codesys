// See https://aka.ms/new-console-template for more information
using System.ComponentModel.Design;
int quant = 1000; //Количество переменных
string datatype = ":INT"; //Тип переменных
string name = "celoe"; //Название переменных

for(int i=0; i <= quant; i++)
{
    if (i == quant)
    {
        Console.Write(name + i + datatype);
    }
    else if (i % 5 == 0)
    {
        Console.WriteLine(name + i + ", ");
    }
    else 
    {
        Console.Write(name + i + ", ");
    }
}

Console.WriteLine(";");
Console.WriteLine("============================="); //разграничение

//Название буфера
string reg = "HoldingRegisters";

for (int i = 0; i <= quant; i++)
{
    Console.WriteLine(reg + "[" + i + "] := " + name + i + ";");
}
