#pragma once

#include "windows/window.h"

namespace rvsim {
class EditorWindow : public Window {
 public:
  EditorWindow(std::shared_ptr<Context> context) : Window(std::move(context)) {}
  void Render() override;

 private:
};

}  // namespace rvsim