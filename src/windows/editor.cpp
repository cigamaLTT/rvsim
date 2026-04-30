#include "TextEditor.h"
#include "imgui.h"
#include "windows/editor_window.h"

namespace rvsim {
void EditorWindow::Render() {
  ImGui::Begin("Text Editor");
  auto area = ImGui::GetContentRegionAvail();
  auto& style = ImGui::GetStyle();
  auto& ctx = this->context();
  auto statusBarHeight = ImGui::GetFrameHeight() + 2.0f * style.WindowPadding.y;
  auto editorSize =
      ImVec2(0.0f, area.y - style.ItemSpacing.y - statusBarHeight);
  auto monospace_font = ctx.monospace_font();
  ImGui::PushFont(monospace_font);
  ctx.text_editor().Render("TextEditor", editorSize);
  ImGui::PopFont();
  if (ImGui::Button(ctx.is_compiling() ? "Compiling..." : "Compile")) {
    if (!ctx.is_compiling()) {
      ctx.StartCompilation();
    }
  }
  ImGui::End();
}
}  // namespace rvsim