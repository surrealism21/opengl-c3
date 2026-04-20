import "dart:io";
import 'package:xml/xml.dart';

// i don't know dart so most of my changes suck
// i don't want to add any packages so my changes suck
// overall this sucks and i could rewrite it but choose not too...

class EnumValue {
  final String value;
  final String name;
  const EnumValue(this.value, this.name);

  String toString() {
    // this is sort of garbage because i've never used Dart
    // Remove GL_ as namespaces exist
    String newname;
    newname = name.toUpperCase().substring(3);

    // if the first char is a number... this is super slow and dumb
    String slop = newname.substring(0, 1);
    if (slop == "1" || slop == "2" || slop == "3" || slop == "4") {
      // just keep GL_
      return "const ${name} = $value;";
    }
    return "const ${newname} = $value;";
  }
}

class Param {
  String name;
  String type;
  Param(this.type, this.name);

  String toString() {
    return "${type}${renameParameter(name)}";
  }
}

class Command {
  final String returnType;
  final String name;
  final List<Param> params;
  const Command(this.returnType, this.name, this.params);

  String toString() {
    var fnName = name.substring(2);
    return "fn ${returnType} ${fnName[0].toLowerCase()} ${fnName.substring(1)} (${params.map((e) => e.toString()).join(", ")}) @extname(${name});";
  }

  String shortName(bool uppercase) {
    String short = name.substring(2);
    if (uppercase) {
      return short[0].toUpperCase() + short.substring(1);
    } else {
      return short[0].toLowerCase() + short.substring(1);
    }
  }

  String defName() {
    return "GL_${shortName(true)}";
  }

  String toDefinition() {
    return "alias ${defName()} = fn $returnType(${params.map((e) => e.toString()).join(", ")});";
  }

  String toBinding() {
    return "${defName()} ${shortName(false)};";
  }

  String toCallFn() {
    return "fn ${returnType}${shortName(false)} (${params.map((e) => e.toString()).join(", ")}) => bindings.${shortName(false)}(${params.map((e) => renameParameter(e.name)).join(",")});";
  }

  String getProc() {
    return "bindings.${shortName(false)} = (${defName()})procAddress(\"${name}\");";
  }
}

// Some parameter names cause issues on C3
String renameParameter(String value) {
  switch (value) {
    case "func":
      return 'func_param';
    case "type":
      return 'value_type';
    default:
      return value;
  }
}

List<EnumValue?> parseEnums(XmlDocument document) {
  return document
      .findAllElements('enum')
      .map((XmlElement node) {
        // var comment = node.getAttribute("comment");
        String? value = node.getAttribute("value");
        String? name = node.getAttribute("name");
        if (value == null) return null;

        return EnumValue(node.getAttribute("value") ?? "", name ?? "");
      })
      .where((element) => element != null)
      .toList();
}

List<Command?> parseCommands(XmlDocument document) {
  return document
      .findAllElements('command')
      .map((XmlElement node) {
        var proto = node.getElement("proto");
        if (proto != null) {
          String? name = proto.getElement("name")!.innerText;
          String type = proto.innerText.replaceAll("const", "");
          List<XmlElement> paramsRaw = node.findAllElements("param").toList();

          List<Param> params = paramsRaw.map((XmlElement value) {
            var name = value.getElement("name")!.innerText;
            var type = value.innerText.replaceAll("const", "");

            type = type.replaceAll("GLDEBUGPROC", "GLdebugproc");
            type = type.replaceAll("GLDEBUGPROCARB", "GLdebugprocarb");
            type = type.replaceAll("GLDEBUGPROCKHR", "GLdebugprockhr");

            return Param(type.substring(0, type.length - name.length), name);
          }).toList();

          return Command(type.substring(0, (type.length - name.length).toInt()), name, params);
        }
      })
      .where((element) => element != null)
      .toList();
}

String Comment(String value) {
  return "\n\n/** \n* $value \n*/ \n";
}

const C3_types = """
alias GLenum = int;
alias GLboolean = bool;
alias GLbitfield = int;
alias GLbyte = ichar;
alias GLubyte = char;
alias GLshort = short;
alias GLushort = ushort;
alias GLint = int;
alias GLuint = int;
alias GLclampx = int;
alias GLsizei = int;
alias GLfloat = float;
alias GLclampf = float;
alias GLdouble = double;
alias GLclampd = double;
alias GLeglClientBufferEXT = void;
alias GLeglImageOES = void;
alias GLchar = char;
alias GLcharARB = char;

alias GLhalf = ushort;
alias GLhalfARB = ushort;
alias GLfixed = int;
alias GLintptr = usz;
alias GLintptrARB = usz;
alias GLsizeiptr = isz;
alias GLsizeiptrARB = isz;
alias GLint64 = long;
alias GLint64EXT = long;
alias GLuint64 = ulong;
alias GLuint64EXT = ulong;
alias GLsync = void*;
alias GLdebugproc = void*;
alias GLdebugprocarb = void*;
alias GLdebugprockhr = void*;
""";

void main() {
  const versions = [
    "GL_VERSION_1_0",
    "GL_VERSION_1_1",
    "GL_VERSION_1_5",
    "GL_VERSION_2_0",
    "GL_VERSION_2_1",
    "GL_VERSION_3_0",
    "GL_VERSION_3_1",
    "GL_VERSION_3_2",
    "GL_VERSION_3_3",
    "GL_VERSION_4_0",
    "GL_VERSION_4_1",
    "GL_VERSION_4_2",
    "GL_VERSION_4_3",
    "GL_VERSION_4_4",
    "GL_VERSION_4_5",
    "GL_VERSION_4_6"
  ];

  // Parse all commands and enums from XML
  final file = new File('dependencies/gl/xml/gl.xml');
  final document = XmlDocument.parse(file.readAsStringSync());

  List<Command?> commandList = parseCommands(document);
  List<EnumValue?> enumList = parseEnums(document);

  // Filter out the versions required
  List<String> versionEnums = [];
  List<String> versionCommands = [];
  document.findAllElements('feature').forEach((XmlElement node) {
    var featureName = node.getAttribute("name");

    if (versions.contains(featureName)) {
      versionEnums.addAll(node.findAllElements("enum").map((value) => value.getAttribute("name")!));
      versionCommands.addAll(node.findAllElements("command").map((value) => value.getAttribute("name")!));
    }
  });

  // Filtered commands and enums
  var commands = commandList.where((value) => versionCommands.contains(value!.name)).toList();
  var enums = enumList.where((value) => versionEnums.contains(value!.name)).toList();

  // This is where the converting to output string happens, very messy.

  // Write to output file

  var output = File('./build/gl.c3');
  output.writeAsStringSync("");

  // Create function bindings placeholder
  String bindingsPlaceholder = Comment("Bindings") +
      "struct GL_bindings {\n" +
      commands.map((value) => value!.toBinding()).join("\n") +
      "\n}" +
      Comment("Bindings memory") +
      "\nGL_bindings bindings;";

  // Create Function definitions
  String fnDefinitions = Comment("Function definitions") +
      commands.map((value) => value!.toDefinition()).join("\n") +
      Comment("GLFW proc definitions") +
      "\nalias ProcFN = fn void* (char*);\n\n";

  // Create Constants list
  String constants = Comment("Constants") + enums.map((value) => value.toString()).join("\n");

  // Init function

  String initFunction =
      "fn void init(ProcFN procAddress) {\n${commands.map((value) => value!.getProc()).join("  \n")}\n} \n";

  String callFunctions = commands.map((value) => value!.toCallFn()).join("\n");

  // Write the whole C3 output file
  output.writeAsStringSync("module gl;" +
      "\n \n" +
      C3_types +
      "\n \n" +
      constants +
      "\n \n" +
      fnDefinitions +
      "\n \n" +
      bindingsPlaceholder +
      "\n \n" +
      initFunction +
      "\n \n" +
      callFunctions);
}
