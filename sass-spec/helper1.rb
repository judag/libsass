#!/usr/bin/env ruby

#This script wil transform a collection of folders and input files to sass implementations
#under a specified directory in such a way that they can be tested with the accompanying
#testrunner.rb script. The transformed hierarchy will be put in a specified location.
#
#For reference, this script will transform a hierarchy that looks like this:
#...
#|-folder1
#| |-subfolder1
#| | |-test1.scss #same file as
#| | |-test2.scss
#| |-subfolder2
#| | |-test1.scss
#| |-test1.scss
#| |-test2.scss
#|-folder2
#...
#
#Into one that looks like this:
#...
#|-folder1
#| |-subfolder1
#| | |-test1
#| | | |-input.scss #this file
#| | | |-expected_output.css #output of the input.scss above when run through sass
#| | |-test2
#| |   |-input.scss
#| |   |-expected_output.css
#| |-subfolder2
#| | |-test1
#| |   |-input.scss
#| |   |-expected_output.css
#| |-test1
#| | |-input.scss
#| | |-expected_output.css
#| |-test2
#|   |-input.scss
#|   |-expected_output.css
#|-folder2
#...
#
#Note that folder2 in the above example would only be created if there was at least one scss file
#somewhere under it in the original file hierarchy (this example assumes there is).

#begin help section
def helpmessage()
	"\nThis script will take a collection of input files to sass implementations and change the\n"+
	"hierarchy in such a way that testrunner.rb can be used to run batches of tests. The\n"+
	"expected_output.css files are generated by running sass (whichever version you have) on the\n"+
	"input files. Sass is assumed to be on you path. View the initial comment of this script for\n"+
	"more detailed info.\n\n"
end

def getusage()
	"Usage: helper1.rb [Options]\n"+
	"\n"+
	"Options:\n"+
	"\t-s=, --source=\t\tSets the directory to recursively search for .scss files (defaults to '.')\n"+
	"\t-d=, --dest=\t\tSets the directory to place the new hierarchy in (defaults to './test-suite/')\n"+
	"\t-h, --help\t\tDisplay this message\n"
end

def exampleusage()
	"Example usage:\n"+
	"./helper.rb -s=myinputcollection\n"+
	"./helper.rb -d=mytestsuitei --skip\n"+
	"./helper.rb -s=myinputcollection -d=mytestsuite\n\n"
end

#print an error message and the usage message, exit with a certain return code
def usage(s,c)
	$stderr.puts(s + getusage())
	exit(c)
end
#end help section

#begin option parsing/sanitizing section
opts = {}

opts[:src] = '.' #set to the default src of .
opts[:dst] = './test-suite/' #set to the default destination of ./test-suite/
opts[:verbose] = false #don't be too talkative by default

loop { case ARGV[0] #this argument parsing allows garbage at the end that doesn't start with '-', modify if necessary
	when /^-(s|-source)=/ then    #to change what to run, modify these lines (or copy them)
		opts[:src] = ARGV.shift.split("=",2)[1] #get the source
		if (opts[:src] == "") #catch empty source (no source was input)
			usage("\nERROR: Must specify a source directory after -s= or --source=.\n\n", 1)
		end
	when /^-(d|-dest)=/ then
		opts[:dst] = ARGV.shift.split("=",2)[1] #get the dir
		if (opts[:dst] == "") #catch empty dir (no dir was input)
			usage("\nERROR: Must specify a destination directory after -d= or --dest=.\n\n", 1)
		end
	when /^-(h|-help)$/ then
		puts helpmessage() + getusage() + exampleusage()
		exit(0)
	when /^-/ then #found an unhandled option, print an error and exit out
		usage("\nERROR: Unknown option: #{ARGV[0].inspect} (make sure to include the '=' for options that require it)\n\n", 2)
	else break
end; }

if !opts[:dst].end_with?("/") then 
	#add a "/" at the end if needed, necessary for globbing to find the needed files
	opts[:dst]+='/' #File::SEPARATOR
end

#not strictly necessary test, but allows a more tailored error message
if File.exists?(opts[:dst]) && !File.directory?(opts[:dst])
	$stderr.puts("\nERROR: Destination specified needs to not be a file. You specified #{opts[:dst]}.\n")
	exit(3)
end
#end option parsing/sanitizing section

#begin actual script
puts("Recursively searching under directory '#{opts[:src]}' for scss files to move to directory '#{opts[:dst]}'.")

test_count = 0
total_test_count = 0

Dir["#{opts[:src]}**/*.scss"].each do |test_file|
	total_test_count += 1

	#get the part of the path that doesn't have the section dictated by source
	#(do this to preserve the existing file hierarchy in src)
	rest_name = test_file[opts[:src].length..-1]

	#get the relative destination of the particular file, which = opts[:dst] + rest_name - .scss + /input.scss
	test_dest_dir = File.join(opts[:dst], rest_name.chomp!(".scss"))

	#mkdir needed directory
	`mkdir -p #{test_dest_dir};`
	
	if !$?.success? #catch an error with making directory
		$stderr.puts("There was a problem making a needed directory (#{test_dest_dir} in particular). Aborting rest of script.")
		exit(2)
	end

	#copy the test file to the destination
	`cp #{test_file} #{File.join(test_dest_dir,"input.scss")}`

	if !$?.success? #catch an error with copying
		$stderr.puts("There was a problem copying #{input_file} to #{test_dest_dir}. Aborting rest of script.")
		exit(3)
	end

	#populate the expected_output.css
	`sass #{File.join(test_dest_dir,"input.scss")} > #{File.join(test_dest_dir, "expected_output.css")}`

	if !$?.success? #catch sass not exiting successfully
		$stderr.puts("ERROR: sass didn't like the input #{File.join(test_dest_dir, "input.scss")} and exited unsuccessfully.\n"+
			     "       This input file will not part of the generated test suite.")
		`rm -r #{test_dest_dir}`
	else
		test_count += 1
	end
end

puts("Found #{total_test_count} total .scss files under #{opts[:src]}. Copied #{test_count} input files.\n"+
     "There may be empty directories, remove them if it bothers you.\n")
#end actual script