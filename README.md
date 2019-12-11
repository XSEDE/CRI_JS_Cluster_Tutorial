# Openstack Cluster Building Tutorial Toolkit

This toolkit contains slides, scripts, and walkthroughs for training users in building HPC-style
clusters in an Openstack cloud. It does assume a fair level of comfort with the linux commandline, 
so please warn your users accordingly (or be prepared to spend time on the basics!).

The expected runtime is about 3-4 hours, given comfort with the commandline. The basic format
is to present the slides first, for about 20-30 minutes, and then guide attendees through 
the steps of building an HPC-style compute resource using SLURM by hand, in order to foster
a deeper understanding of the systems they use or may be interested in learning to run. 
This could easily be expanded to several sessions if interspersed with instruction in linux
commandline useage, and we would be happy to consult on appropriate topics/breakpoints.

The slides and walkthrough currently reference the Jetstream cloud, though the material
is useable on any Openstack cloud - some search and replace may be necessary to avoid confusion, 
however. The authors are happy to help; please feel free to reach out either via Github or 
by emailing `help@xsede.org` (PLEASE put 'XCRI' in the subject, so that the ticket will reach us
quickly).

If providing material on commandline useage to users beforehand, we have found the book 
'[Unix for the Beginning Mage](http://unixmages.com/the-first-book/)' 
rather helpful and amusing, though they should expect to spend at least a couple of
hours getting comfortable with the commandline environment. For this tutorial, comfort with Chapters
1-3 is minimally enough, though chapters 4-7 are also quite helpful for a deeper understanding. 

This tutorial currently uses `vim` for the text editor, though new users may be more comfortable
with something like `nano`. Feel free to adjust as needed!
