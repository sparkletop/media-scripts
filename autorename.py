import os
import time
import argparse
import uuid
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class Watcher(FileSystemEventHandler):
    """A class that watches a folder for changes and renames it with a unique id and a sequence number after a period of inactivity."""

    def __init__(self, folder, interval, grace_period, id):
        """Initialize the watcher with the folder path and other parameters.
        Args:
            folder (str): The path to the folder to be watched and renamed.
            interval (int): The wait interval to check for directory tree changes in seconds.
            grace_period (int): The grace period of inactivity before renaming in seconds.
            id (str): A unique identifier string.
        """
        
        self.root_dir = os.path.abspath(folder)

        self.id = id
        self.interval = interval
        self.grace_period = grace_period
        self.timestamp()
        self.watching = True

    def on_created(self, event):
        print(f"{time.ctime()}: New {'subdirectory' if os.path.isdir(event.src_path) else 'file'} created: {event.src_path}")
        self.timestamp()

    def on_modified(self, event):
        self.timestamp()
    
    def on_deleted(self, event):
        print(f"{time.ctime()}: Path deleted: {event.src_path}")
        self.timestamp()
        if event.src_path == self.root_dir:
            print(f"{time.ctime()}: Root directory {self.root_dir} disappeared, stopping watcher")
            self.watching = False
    
    def timestamp(self):
        self.last_change_time = time.time()

    # Check whether grace period has expired
    def check_directory(self):
        if time.time() - self.last_change_time > self.grace_period:
            new_name = f"{self.root_dir}_{self.id}"
            os.rename(self.root_dir, new_name)
            print(f"{time.ctime()}: Grace period ended, renaming {self.root_dir} to {new_name}")
            self.watching = False
            
    def awaken(self):
        print(f"{time.ctime()}: Waiting for root directory at {self.root_dir}")
        # Wait until the folder exists, otherwise the observer throws an error
        try:
            while not os.path.isdir(self.root_dir):
                time.sleep(self.interval)
        except KeyboardInterrupt:
            print(f"{time.ctime()}: Received SIGINT, quitting. Root directory at {self.root_dir} not found")
            exit(0)
        
        # Root folder exists, start observing for changes
        print(f"{time.ctime()}: Root directory detected, starting to watch for changes")
        self.observer = Observer()
        self.observer.schedule(self, self.root_dir, recursive=True)
        self.observer.start()
        self.timestamp()

        try:
            while self.watching:
                time.sleep(self.interval)
                self.check_directory()
        except KeyboardInterrupt:
            self.observer.stop()
            self.observer.join()
            print(f"{time.ctime()}: Received SIGINT, quitting. Was watching {self.root_dir} for changes, grace period had not expired.")
            exit(1)
        
        self.observer.stop()
        self.observer.join()

def main():
    parser = argparse.ArgumentParser(description="Automatically add sequence number to folder name after a period of inactivity.")
    parser.add_argument("-i", "--interval", type=int, default=10, help="Wait interval to check for directory tree changes (seconds, default is 10).")
    parser.add_argument("-g", "--grace_period", type=int, default=600, help="Grace period of inactivity before renaming (seconds, default is 600).")
    parser.add_argument("-s", "--sequence_offset", type=int, default=0, help="Initial number in sequence (default is 0).")
    parser.add_argument("-z", "--leading_zeros", type=int, default=2, help="Number of leading zeros (default is 2).")
    parser.add_argument("folder", type=str, help="Path to the folder to be watched and eventually renamed with suffix of _00, _01, _02 etc.")

    args = parser.parse_args()
    
    uid = f"{str(uuid.uuid4())[:8]}"
    sequence_num = args.sequence_offset

    while True:
        w = Watcher(
            interval=args.interval,
            grace_period=args.grace_period,
            folder=args.folder,
            id=f"{uid}_{sequence_num:0{args.leading_zeros}d}"
        )
        w.awaken()
        sequence_num += 1

if __name__ == "__main__": main()
