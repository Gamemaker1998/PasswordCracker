#include <stdio.h>
#include <iostream>
#include <stdlib.h>
#include <cmath>
#include <ctime>
#include <Windows.h>

#define CUDACRACK TRUE
#define MAX_DIGITS 100
#define PW_CHARSET 58

bool crackPassword(char*, int, char*);

extern bool init(char*, int, int, char*);


int main()
{
	char buffer[MAX_DIGITS];
	char* password;
	char* endPassword;
	int mode;
	int digits;

	std::cout << "Geben Sie ein Passwort zum knacken ein: ";
	scanf("%s", buffer);
	printf("Laenge: %d\n\n", (digits = strlen(buffer)));
	std::cout << std::endl << "Wie wollen sie dieses Passwort cracken?" << std::endl;
	printf("1) Mit CPU\n2) Mit GPU\n\nMode: ");
	scanf("%d", &mode);
	std::cout << std::endl << std::endl;

	password = new char[digits];
	endPassword = new char[digits+1];
	memcpy(password, buffer, sizeof(char) * digits);
	memset(endPassword, 0, sizeof(char) * (digits + 1));

	// Messure time
	clock_t timer = clock();
	bool cracked = false;
	
if(mode == 1)
	cracked = crackPassword(password, digits, endPassword);
else if(mode == 2)
	cracked = init(password, digits, PW_CHARSET, endPassword);

	clock_t interval = ((clock() - timer) / (float)(CLOCKS_PER_SEC)) * 1000;

	if(cracked)
	{
		printf("\nDas Passwort lautet: %s\n", endPassword);
		std::cout << "It took exactly: " << interval << " milliseconds to guess the password" << std::endl << std::endl;
	}
	else
		printf("\nDas Passwort konnte nicht gecracked werden\n\n");

	system("PAUSE");

	delete password;
	delete endPassword;

	return 0;
}


bool crackPassword(char* password, int digits, char* endPassword)
{
	char* currentPw = new char[digits];
	memset(currentPw, 'A', digits * sizeof(char));

	long long maxGuesses = (long long)(pow(PW_CHARSET, digits));
	int lastCharacterIndex = digits-1;
	
	bool cracked = false;

	for(long long i=0;  i<maxGuesses;  i++)
	{
		if(strncmp(currentPw, password, digits) == 0)
		{
			strncpy(endPassword, currentPw, sizeof(char) * digits);
			cracked = true;
			break;
		}
		
		currentPw[lastCharacterIndex]++;

		for(int index=lastCharacterIndex;  currentPw[index] -'A' >= PW_CHARSET && index > 0;  index--)
		{
			currentPw[index] = 'A';
			currentPw[index-1]++;
		}
	}

	//delete currentPw;
	return cracked;
}