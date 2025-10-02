Prequisites and steps to run:
What you will get:
• A Docker image with all build tools and a shared memory segment for PG (you don’t nec-
essarily need to use Docker in your local Mac laptop; other platforms, like a Linux remote
server, a WSL in your local Windows laptop, can still work, but all the document is based
on a local Mac laptop with the Docker environment, so you need to make some adjusts if
you use other platforms).
• A locally installed, debug-enabled PostgreSQL 17.4 under ˜/postgresql-17.4.
• A database cluster at ˜/databases managed via pg_ctl.
• Passwordless sudo for /usr/bin/gdb to simplify attaching a debugger.
• VS Code launch configuration for on-the-fly GDB attachment to postgresql.
• Loaded IMDB/JOB tables and ready-to-run JOB SQL queries.
2 Prerequisites
• Docker installed on the host (Again, this is not necessary if you choose other platforms).
• (Optional) Visual Studio Code with the C/C++ extension for GDB-attach debugging.
• Enough disk space and memory for PostgreSQL sources and the IMDB/JOB data.

4 Environment Setup in Docker
4.1 Build and Run the Container
Listing 1: Build and run the Docker container
# From the folder containing your Dockerfile:
docker build -t csci543_image:latest .
# Large /dev/shm (32 GB), privileged mode, and ptrace caps for debugging:
docker run --name csci543_container --privileged -it \
--shm-size=32g \
--cap-add=SYS_PTRACE --cap-add=CAP_SYS_ADMIN \
csci543_image:latest

4.2 Fetch and Build PostgreSQL 17.4
Listing 2: Download, build (debug), and install PostgreSQL 17.4
cd ~
wget https://ftp.postgresql.org/pub/source/v17.4/postgresql-17.4.tar.gz
tar xzf postgresql-17.4.tar.gz
cd postgresql-17.4/
CFLAGS=-O0 ./configure --prefix=/home/qihan/postgresql-17.4 --enable-debug
# Choose a reasonable -j value for your CPU, avoid using the command ‘‘sudo make -j’’
sudo make -j8
make install
# Use this command if you have modified the codebase and want to recompile. Also
→restart the database instance.
make clean
# Put the new ’bin’ directory first on PATH
echo ’export PATH=/home/qihan/postgresql-17.4/bin:$PATH’ >> ~/.bashrc
source ~/.bashrc

4.3 Initialize and Control the Instance
Listing 3: Initialize, start, restart, and stop the server
cd ~
pg_ctl -D /home/imrkale1/databases initdb
pg_ctl -D /home/imrkale1/databases -l logfile start
# a combined command for stop and start
pg_ctl -D /home/imrkale1/databases -l logfile restart
# When done:
pg_ctl -D /home/imrkale1/databases stop

5.1 Prepare and Load
Listing 7: Recover and load IMDB/JOB into PostgreSQL
# Get the loader (drag ’load_imdb’ folder from the zip file or clone the repo from
→https://github.com/Tsihan/CSCI543-25Fall-Project1)
cd ~/load_imdb
# Download IMDB data for JOB
mkdir -p datasets/job && pushd datasets/job
# If this link becomes invalid, please contact the TA
wget -c https://event.cwi.nl/da/job/imdb.tgz
tar -xvzf imdb.tgz && popd
# Add headers expected by the loader scripts
bash ./prepend_imdb_headers.sh
# (tmux recommended to avoid accidental disconnects)
bash load-postgres/load_job_postgres.sh /home/qihan/load_imdb/datasets/job

5.2 Verify and Run a Test Query
Listing 8: Connect with psql and run a JOB query file
# Adjust -U to your actual database role (often the current OS user, e.g.,
psql -U qihan -d imdbload
-- inside psql:
\i /home/qihan/load_imdb/job_queries/1a.sql
# If it shows some reasonable results, then you are good!
# Now we exit the ses
