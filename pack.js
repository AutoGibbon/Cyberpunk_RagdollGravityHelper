const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Configuration
const SOURCE_R6_FOLDER = "./r6";
const OUTPUT_ZIP = "./r6.zip";

// Helper function to check if file should be excluded
function shouldExcludeFile(filePath) {
	const fileName = path.basename(filePath).toLowerCase();
	return fileName.includes("cursorrules") || fileName.includes(".cursorrules");
}

// Helper function to recursively get all files, excluding cursorrules
function getAllFiles(dirPath, basePath = "") {
	const files = [];
	const entries = fs.readdirSync(dirPath, { withFileTypes: true });

	for (const entry of entries) {
		const fullPath = path.join(dirPath, entry.name);
		const relativePath = path.join(basePath, entry.name);

		if (entry.isDirectory()) {
			files.push(...getAllFiles(fullPath, relativePath));
		} else if (!shouldExcludeFile(fullPath)) {
			files.push(relativePath);
		}
	}

	return files;
}

// Comments out any active LogChannel(...) calls in Logging.reds files so a release
// build never ships with debug logging left on. Returns the list of files it changed.
function disableLogging(files) {
	const changed = [];
	for (const relPath of files) {
		if (path.basename(relPath) !== "Logging.reds") {
			continue;
		}
		const content = fs.readFileSync(relPath, "utf8");
		const updated = content
			.split("\n")
			.map((line) => {
				const trimmed = line.trimStart();
				if (trimmed.startsWith("LogChannel(")) {
					const indent = line.slice(0, line.length - trimmed.length);
					return `${indent}// ${trimmed}`;
				}
				return line;
			})
			.join("\n");
		if (updated !== content) {
			fs.writeFileSync(relPath, updated);
			changed.push(relPath);
		}
	}
	return changed;
}

async function pack() {
	try {
		console.log("Starting pack process...");
		console.log(`Source folder: ${SOURCE_R6_FOLDER}`);
		console.log(`Output file: ${OUTPUT_ZIP}`);

		// Remove existing zip if it exists
		if (fs.existsSync(OUTPUT_ZIP)) {
			console.log("Removing existing zip file...");
			fs.unlinkSync(OUTPUT_ZIP);
		}

		// Get all files to include
		console.log("Scanning files...");
		const files = getAllFiles(SOURCE_R6_FOLDER, "r6");

		// Always disable logging before packing a release build.
		const loggingFilesDisabled = disableLogging(files);
		if (loggingFilesDisabled.length > 0) {
			console.log(`Disabled active logging in: ${loggingFilesDisabled.join(", ")}`);
		}
		console.log(`Found ${files.length} files to pack`);

		// Create zip using 7zip
		console.log("Creating zip archive...");
		const filesList = files.map((f) => `"${f}"`).join(" ");
		const command = `7z a "${path.resolve(OUTPUT_ZIP)}" ${filesList}`;

		execSync(command, { cwd: ".", stdio: "inherit" });

		console.log("\n✅ Pack completed successfully!");
		console.log(`Created: ${OUTPUT_ZIP}`);
	} catch (error) {
		console.error("\n❌ Pack failed:", error.message);
		process.exit(1);
	}
}

// Run pack
pack();
