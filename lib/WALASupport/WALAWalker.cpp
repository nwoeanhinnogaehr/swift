#include <stdlib.h>
#include <jni.h>
#include <csetjmp>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>

#include "swift/SIL/SILLocation.h"
#include "swift/WALASupport/WALAWalker.h"

#include "launch.h"
#include "Exceptions.h"
#include "CAstWrapper.h"

using namespace swift;

void print_object(JNIEnv *java_env, jobject object) {
    jclass Object = java_env->FindClass("java/lang/Object");
	  
    jmethodID toString = java_env->GetMethodID(Object, "toString", "()Ljava/lang/String;");

    jstring msg = (jstring) java_env->CallObjectMethod(object, toString);

    jboolean f = false;
    const char *text = java_env->GetStringUTFChars(msg, &f);
	  
    printf("FOO: %s\n", text);
	  
    java_env->ReleaseStringUTFChars(msg, text);
}

// Gets the directory-less string version of the given filename.
string getShortFilename(string filenamePath, string splitString, unsigned offset = 0) {

	// Split the filepath
	size_t splitPoint = filenamePath.find_last_of(splitString);
	return filenamePath.substr(splitPoint + offset);

}

// Takes the shortFilename, concatenates the $SWIFT_WALA_OUTPUT dir, and writes the result
// to char *outfileName.  Used for dump() and open().
void getOutputFilename(raw_ostream &outstream, 
	string shortFilename, char *outfileName) {
	// Get output dir	
	string outputDir = getenv("SWIFT_WALA_OUTPUT");
	
	// Concatenate to output full path
	sprintf(outfileName, "%s/%s.txt", outputDir.c_str(), shortFilename.c_str());

	outstream << "\t [FILENAME]: " << shortFilename << "\n";	// DEBUG
	outstream << "\t [FILEPATH]: " << outfileName << "\n";		// DEBUG
	
	// Check if file exists; if so, try to make the file unique
	unsigned i = 0;
	ifstream fileCheck;
	fileCheck.open(outfileName);
	while (fileCheck && i < 100) {
		fileCheck.close();
		sprintf(outfileName, "%s_%u.txt", outfileName, i);
		fileCheck.open(outfileName);
		i++;
	}
	
}

// Prints the path to outstream, and also to outfile if it is open and writeable.
void printPath(raw_ostream &outstream, ofstream &outfile, string filenamePath) {
	outstream << "\t [SOURCE] file: " << filenamePath << "\n\n";

	if (outfile.is_open()) {
		outfile << "[SOURCE] file: " << filenamePath << "\n\n";
	}
	
}

// Prints the SIL to the outfile if it is open and writeable.
void printSIL(ofstream &outfile, char *outputFilename, SILModule &SM) {
	if (outfile.is_open()) {
		SM.dump(outputFilename);
	}
}

// Outputs the mangled SILFunction name to outstream.
void printSILFunctionInfo(raw_ostream &outstream, SILFunction &func) {
	// Print function name
	outstream << "\t -- [FUNCTION] Name: " << func.getName() << "\n";
}

// Outputs the SILBasicBlock ID to outstream.
void printSILBasicBlockInfo(raw_ostream &outstream, SILBasicBlock &bb) {

	// Print SILBasicBlock ID
	SILPrintContext context(outstream);
	auto bbID = context.getID(&bb);
	outstream << "\t ---- [BASIC BLOCK] ID: " << bbID << "\n";
}

// Prints the sourcefile, line, and column info to outstream.
void printInstrDebugLocInfo(raw_ostream &outstream, SILInstruction &instr, SourceManager &srcMgr) {

	// Get file-line-col information for the source
	SILLocation debugLoc = instr.getDebugLocation().getLocation();
	SILLocation::DebugLoc debugInfo = debugLoc.decodeDebugLoc(srcMgr);
	
	size_t splitPoint = debugInfo.Filename.find("swift-source/");
	string splitString = debugInfo.Filename.substr(splitPoint);
	
	outstream << "\t\t\t ----> Source: " << splitString;
	outstream << ", Line: " << debugInfo.Line << ", Col: " << debugInfo.Column << "\n";
}

// Outputs to outstream whether instr may release, write to memory, read from memory,
// trap the instruction, or potentially have side effects.
void printInstrMemoryReleasingInfo(raw_ostream &outstream, SILInstruction &instr) {

	switch (instr.getMemoryBehavior()) {
		case SILInstruction::MemoryBehavior::None : {
			break;
		}
		case SILInstruction::MemoryBehavior::MayRead : {
			outstream << "\t\t\t [MEM-R]: May read from memory. \n";
			break;
		}
		case SILInstruction::MemoryBehavior::MayWrite : {
			outstream << "\t\t\t [MEM-W]: May write to memory. \n";
			break;
		}
		case SILInstruction::MemoryBehavior::MayReadWrite : {
			outstream << "\t\t\t [MEM-RW]: May read or write memory. \n";
			break;
		}
		case SILInstruction::MemoryBehavior::MayHaveSideEffects : {
			outstream << "\t\t\t [EFF]: May have side effects. \n";
		}
	}
	
	switch (instr.getReleasingBehavior()) {
		case SILInstruction::ReleasingBehavior::DoesNotRelease : {
			outstream << "\t\t\t [REL]: Does not release memory. \n";
			break;
		}
		case SILInstruction::ReleasingBehavior::MayRelease : {
			outstream << "\t\t\t [REL]: May release memory. \n";
			break;
		}
	}
}

// Goes over all operands on the SILInstr and prints them out.
void printInstrOpInfo(raw_ostream &outstream, SILInstruction &instr) {

	// Output operand information
	for (unsigned i = 0; i < instr.getNumOperands(); ++i) {
		SILValue v = instr.getOperand(i);
		outstream << "\t\t\t **** Operand #" << i << ": " << v << "\n";
	}
}

// The big one - gets the ValueKind of the SILInstruction then goes through the
// mega-switch to handle appropriately.
void printInstrValueKindInfo(raw_ostream &outstream, SILInstruction &instr) {

	//
	auto instrKind = instr.getKind();
	switch (instrKind) {
	
		case ValueKind::ApplyInst : {
			// Cast to ValueKind::ApplyInst 
			ApplyInst *applyInst = &cast<ApplyInst>(instr);
			
			// Iterate args and output SILValue
			for (unsigned i = 0; i < applyInst->getNumArguments(); ++i) {
				SILValue v = applyInst->getArgument(i);
				outstream << "\t\t ***** " << v << "\n";
			}
			break;
		}
		default: {
			outstream << "\t\t ##### Not an ApplyInst \n";
			break;
		}
	}
}

// Handles all the SILInstruction printing and management.
void printSILInstrInfo(raw_ostream &outstream, 
	SILInstruction &instr, SourceManager &srcMgr) {
	unsigned i = 0;
	
	outstream << "\t\t ---- -- [INSTRUCTION] #" << i << ": \n";
	
	printInstrDebugLocInfo(outstream, instr, srcMgr);
	printInstrMemoryReleasingInfo(outstream, instr);
	printInstrOpInfo(outstream, instr);
	printInstrValueKindInfo(outstream, instr);
}

// Break down SILModule -> SILFunction -> SILBasicBlock -> SILInstruction -> SILValue
void getBreakdown(raw_ostream &outstream, 
	SILModule &SM, SourceManager &srcMgr) {

	// Iterate over SILFunctions
	for (auto func = SM.begin(); func != SM.end(); ++func) {
	
		printSILFunctionInfo(outstream, *func);
	
		// Iterate over SILBasicBlocks
		for (auto bb = func->begin(); bb != func->end(); ++bb) {
		
			printSILBasicBlockInfo(outstream, *bb);
			
			for (auto instr = bb->begin(); instr != bb->end(); ++instr) {
			
				printSILInstrInfo(outstream, *instr, srcMgr);
			
			}
		}	
	}
}

// Main WALAWalker implementation.
void analyzeSILModule(SILModule &SM) {

	// Modes and settings
	bool outputPath = true;
	bool outputSIL = true;

	// Output configurations
	raw_ostream &outstream = llvm::outs();
	
	// SILModule-derived information
	SourceManager &srcMgr = SM.getSourceManager();
	string filenamePath = SM.getSwiftModule()->getModuleFilename().str();
	
	// Get output filename
	string splitString = "/";
	string shortFilename = getShortFilename(filenamePath, splitString, 1);
	char outputFilename[1024];
	getOutputFilename(outstream, shortFilename, outputFilename);
	
	// Open output file for writing
	ofstream outfile;
	outfile.open(outputFilename, ios::out);
	if (!outfile.is_open()) {
		outstream << "\t[FILE]: Error opening " << outputFilename << ".";
		outstream << "  Will not dump outputs." << "\n";	
	}
	
	// Print and file-output source path information
	if (outputPath) { printPath(outstream, outfile, filenamePath); }

	// Dump SIL for SILModule to output file.
	if (outputSIL) { printSIL(outfile, outputFilename, SM); }
	
	// Iterate SILModule -> SILFunction -> SILBasicBlock -> SILInstruction
	getBreakdown(outstream, SM, srcMgr);
}

void WALAWalker::foo() {
  char *walaHome = getenv("WALA_HOME");
  char *swiftWalaHome = getenv("SWIFT_WALA_HOME");
  char classpath[1024];
  sprintf(classpath, "%s/com.ibm.wala.util/target/classes:%s/com.ibm.wala.shrike/target/classes:%s/com.ibm.wala.core/target/classes:%s/com.ibm.wala.cast/target/classes:%s/com.ibm.wala.cast.swift/bin", walaHome, walaHome, walaHome, walaHome, swiftWalaHome);

  JNIEnv *java_env = launch(classpath);
  TRY(cpp_ex, java_env)

      jclass xlatorCls = java_env->FindClass("com/ibm/wala/cast/swift/SwiftToCAstTranslator");
      THROW_ANY_EXCEPTION(cpp_ex);

      jmethodID xlatorInit = java_env->GetMethodID(xlatorCls, "<init>", "()V");
      THROW_ANY_EXCEPTION(cpp_ex);

      jobject xlator = java_env->NewObject(xlatorCls, xlatorInit);
      THROW_ANY_EXCEPTION(cpp_ex);

      CAstWrapper CAst(java_env, cpp_ex, xlator);
      THROW_ANY_EXCEPTION(cpp_ex);

      jobject x = CAst.makeConstant(3.7);

      print_object(java_env, x);
      THROW_ANY_EXCEPTION(cpp_ex);
      
  START_CATCH_BLOCK()

      if (java_env->ExceptionCheck()) {
	  jthrowable real_ex = java_env->ExceptionOccurred();
	  
	  print_object(java_env, real_ex);
      }
  
  END_CATCH_BLOCK()
}

// Test function for breaking down SILModule SM and exploring integration
void WALAWalker::print(SILModule &SM) {
	analyzeSILModule(SM);
}