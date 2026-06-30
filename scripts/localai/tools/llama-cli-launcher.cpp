#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <iostream>

using llama_cli_fn = int(__cdecl *)(int, char **);

int main(int argc, char ** argv) {
    HMODULE dll = LoadLibraryW(L"llama-cli-impl.dll");
    if (dll == nullptr) {
        std::cerr << "Failed to load llama-cli-impl.dll, error " << GetLastError() << "\n";
        return 127;
    }

    auto llama_cli = reinterpret_cast<llama_cli_fn>(GetProcAddress(dll, "?llama_cli@@YAHHPEAPEAD@Z"));
    if (llama_cli == nullptr) {
        std::cerr << "Failed to find llama_cli export, error " << GetLastError() << "\n";
        return 127;
    }

    return llama_cli(argc, argv);
}
