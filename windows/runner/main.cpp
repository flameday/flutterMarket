#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <fstream>
#include <string>
#include <stdlib.h>
#include <ctime>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  
  // Get window title from environment variable
  std::wstring windowTitle = L"EUR/USD Chart Viewer"; // Default title
  
  wchar_t* configEnv = nullptr;
  size_t len = 0;
  if (_wdupenv_s(&configEnv, &len, L"APP_CONFIG") == 0 && configEnv != nullptr) {
    std::wstring configStr(configEnv);
    size_t separatorPos = configStr.find(L',');
    if (separatorPos != std::wstring::npos) {
      std::wstring titleKey = configStr.substr(0, separatorPos);
      if (titleKey == L"EURUSD-m5") {
        windowTitle = L"EUR/USD-5m";
      } else if (titleKey == L"EURUSD-m30") {
        windowTitle = L"EUR/USD-30m";
      } else if (titleKey == L"EURUSD-h4") {
        windowTitle = L"EUR/USD-4h";
      } else {
        windowTitle = titleKey;
      }
    }
    free(configEnv);
  }
  
  if (!window.Create(windowTitle.c_str(), origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
