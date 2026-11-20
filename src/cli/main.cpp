#include <print>

#include "simulator/simulator.h"

int main() {
  std::println("rvsim-cli {}", rvsim::CoreVersion());
  return 0;
}
