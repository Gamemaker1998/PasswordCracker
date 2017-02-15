
#include <stdio.h>
#include <string.h>
#include <cmath>
#include <Windows.h>

const int CUDA_MAX_BLOCKS = pow(2, 16);

struct configStruct
{
	cudaDeviceProp properties;
	dim3 threads;
	dim3 blocks;
	unsigned long long totalThreads;
	unsigned long long threadsPerLoop;
	unsigned long long loops;
	unsigned long long totalBlocks;
	unsigned int totalRegistersPerFunction = 7;
	unsigned long long totalRegistersPerBlock;
}mainConfig;

void showSpecs();
void initRequirements(int, int);


/* Funzt aber Speicher ineffizient
__global__ void crack(char* d_password, char* d_passwordPerThread, int digits, int charset, long distributor, char* endPassword, bool* cracked)
{
	int x = threadIdx.x;
	int index = x * digits;

	if(x >= distributor)
		return;

	int number = x;

	for(int i=0;  i<digits && distributor > 0;  i++)
	{
		d_passwordPerThread[index + i] = (int)(number / (distributor / charset)) + 'A';
		distributor = (int)(distributor / charset);
		number = (int)(number % distributor);

		if(d_passwordPerThread[index + i] != d_password[i])
			return;
	}

	memcpy(endPassword, &(d_passwordPerThread[index]), sizeof(char) * digits);
	*cracked = true;
}*/


__global__ void test(unsigned long long* number, bool* guessed)
{
	unsigned long long id = (unsigned long long)((blockIdx.x + blockIdx.y * gridDim.x) * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x);

	unsigned long long a = 1;
	unsigned long long b = -2;
	unsigned long long erg = a + b;

	if(id == *number)
		*guessed = true;
}

/*int main(int argc, char* argv[])
{
	dim3 blocks(65535);
	dim3 threads(1024, 1, 1);

	unsigned long long number = 0;
	bool guessed = false;

	scanf("%llu", &number);

	unsigned long long* d_number;
	bool* d_guessed;

	cudaMalloc(&d_number, sizeof(long long));
	cudaMemcpy(d_number, &number, sizeof(long long), cudaMemcpyHostToDevice);

	cudaMalloc(&d_guessed, sizeof(bool));

	test<<<blocks, threads>>>(d_number, d_guessed);
	cudaError_t error = cudaGetLastError();
	printf("\n%s: %s\n\n", cudaGetErrorName(error), cudaGetErrorString(error));

	cudaMemcpy(&guessed, d_guessed, sizeof(bool), cudaMemcpyDeviceToHost);

	if(guessed)
		printf("\nDie Zahl %llu wurde erraten\n\n", number);
	else
		printf("\nDie Zahl %llu wurde nicht erraten\n\n", number);

	system("PAUSE");
}*/


__global__ void crack(char* d_password, int digits, int charset, unsigned long long distributor, char* endPassword, bool* cracked, unsigned long long offset)
{
	unsigned long long id = (unsigned long long)((blockIdx.x + blockIdx.y * gridDim.x) * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x + offset);

	if (id >= distributor)
		return;

	// Werte sichern
	unsigned long long distributorSave = distributor;

	unsigned long long number = id;
	char currentCharacter = '\0';

	for (int i = 0; i<digits && distributor > 0; i++)
	{
		currentCharacter = (char)(number / (distributor / charset)) + 'A';
		distributor = (unsigned long long)(distributor / charset);
		number = (unsigned long long)(number % distributor);

		if (currentCharacter != d_password[i])
			return;
	}

	distributor = distributorSave;
	number = id;
	for (int i = 0; i<digits && distributor > 0; i++)
	{
		endPassword[i] = (int)(number / (distributor / charset)) + 'A';
		distributor = (int)(distributor / charset);
		number = (int)(number % distributor);
	}
	*cracked = true;
}


__host__ bool init(char* password, int digits, int pwCharset, char* endPassword)
{
	char* d_password;
	char* d_endPassword;
	bool* d_cracked;

	bool h_cracked = false;

	initRequirements(digits, pwCharset);

	showSpecs();

	cudaMalloc(&d_password, sizeof(char) * digits);
	cudaMemcpy(d_password, password, digits * sizeof(char), cudaMemcpyHostToDevice);

	cudaMalloc(&d_endPassword, sizeof(char) * digits);

	cudaMalloc(&d_cracked, sizeof(bool));

	printf("Password to crack: %.*s\n", digits, password);

	for(unsigned long long i=0;  i<mainConfig.loops;  i++)
	{
		crack<<<mainConfig.blocks, mainConfig.threads>>>(d_password, digits, pwCharset, mainConfig.totalThreads, d_endPassword, d_cracked, i*mainConfig.threadsPerLoop);
		/*cudaError_t error = cudaGetLastError();
		printf("Error = %s: %s\n", cudaGetErrorName(error), cudaGetErrorString(error));*/
	}

	cudaMemcpy(endPassword, d_endPassword, sizeof(char) * digits, cudaMemcpyDeviceToHost);
	cudaMemcpy(&h_cracked, d_cracked, sizeof(bool), cudaMemcpyDeviceToHost);

	cudaFree(d_password);
	cudaFree(d_endPassword);
	cudaFree(d_cracked);

	return h_cracked;
}

void showSpecs()
{
	printf("\nGPU CUDA specs:\n\tName: %s\n\tShared mem per block: %uB\n\tTotal global mem: %uB\n", mainConfig.properties.name, mainConfig.properties.sharedMemPerBlock, mainConfig.properties.totalGlobalMem);
	printf("\tRegisters per block: %u\n", mainConfig.properties.regsPerBlock);
	printf("\n\n");
	printf("Requirements:\n");
	printf("\tNumber of blocks: %llu\n\tTotal length: %llu\n\tMaximum length: %u\n", mainConfig.totalBlocks, mainConfig.totalThreads, mainConfig.properties.totalGlobalMem);
	printf("\tBlock dimensioning\n\t\ty: %u\n\t\tx: %u\n", mainConfig.blocks.y, mainConfig.blocks.x);
	printf("\tRegisters per Block: %llu\n\tRegisters per function: %u\n", mainConfig.totalRegistersPerBlock, mainConfig.totalRegistersPerFunction);
	printf("\tLoops: %llu\n\tThreads per loop: %llu\n", mainConfig.loops, mainConfig.threadsPerLoop);
	printf("\n\n");
}

void initRequirements(int digits, int pwCharset)
{
	int deviceID;
	cudaGetDevice(&deviceID);
	cudaGetDeviceProperties(&mainConfig.properties, deviceID);

	mainConfig.totalThreads = (unsigned long long)(pow(pwCharset, digits));

	mainConfig.totalBlocks = (unsigned long long)(1 + mainConfig.totalThreads / mainConfig.properties.maxThreadsPerBlock);
	mainConfig.threads = {(unsigned int)mainConfig.properties.maxThreadsPerBlock, (unsigned int)1, (unsigned int)1};

	unsigned int value = pow(2, 16) - 1;

	mainConfig.blocks.z = 1;
	mainConfig.blocks.y = 1;
	if(mainConfig.totalBlocks > value)
		mainConfig.blocks.x = value;
	else
		mainConfig.blocks.x = mainConfig.totalBlocks;

	mainConfig.loops = (unsigned long long)(1 + mainConfig.totalBlocks / value);
	mainConfig.threadsPerLoop = (unsigned long long)(mainConfig.blocks.x * mainConfig.threads.x);
	
	mainConfig.totalRegistersPerBlock = (mainConfig.threads.x * mainConfig.threads.y * mainConfig.threads.z) * mainConfig.totalRegistersPerFunction;
}

