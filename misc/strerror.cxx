#include <iostream>
#include <string>
#include <sstream>
#include <typeinfo>
#include <cstring>

template <class T> T convert(const std::string & str) {
  std::istringstream ist(str + '\n');
  T t;
  ist >> t;
  if (ist.good()) {
    return t;
  }
  else {
    std::cerr
      << "Failed to convert '" << str
      << "' to '" << typeid(T).name() << "'" << std::endl;
    throw;
  }
}

int main(int argc, char * argv[]) {
  for (int i = 1; i != argc; ++i) {
    int num = convert<int>(argv[i]);
    std::cout << num << " -> " << std::strerror(num);
  }

  return 0;
}
