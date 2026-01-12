"""
Posterizarr Scheduler Module
Handles automated script execution based on configured schedules
"""

import json
import logging
import asyncio
import threading
import os
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Union
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger  # Added for Every X logic
from apscheduler.jobstores.memory import MemoryJobStore
from apscheduler.executors.asyncio import AsyncIOExecutor
import subprocess
import platform
import pytz

# Try to import psutil for process checking
try:
    import psutil

    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    logging.warning(
        "psutil not available - stale running file detection will be limited"
    )

logger = logging.getLogger(__name__)

IS_DOCKER = (
    os.path.exists("/.dockerenv")
    or os.environ.get("DOCKER_ENV", "").lower() == "true"
    or os.environ.get("POSTERIZARR_NON_ROOT", "").lower() == "true"
)


class PosterizarrScheduler:
    """Manages scheduled execution of Posterizarr script in normal mode"""

    def __init__(self, base_dir: Path, script_path: Path):
        logger.info("=" * 60)
        logger.info("INITIALIZING POSTERIZARR SCHEDULER")
        logger.info(f"Base directory: {base_dir}")
        logger.info(f"Script path: {script_path}")
        logger.debug(f"Docker environment: {IS_DOCKER}")

        self.base_dir = base_dir
        self.script_path = script_path
        self.config_path = base_dir / "scheduler.json"
        self.scheduler = None
        self.current_process = None
        self.is_running = False
        self._scheduler_initialized = False
        # Use a threading.RLock for all methods (sync and async)
        self._lock = threading.RLock()

        # Initialize timezone cache
        self._cached_timezone = None

        logger.debug(f"Config file path: {self.config_path}")
        logger.debug(f"psutil available: {PSUTIL_AVAILABLE}")

        # Determine initial timezone (ENV has priority in Docker)
        initial_timezone = self._get_timezone()
        logger.debug(f"Timezone determined: {initial_timezone}")

        # Initialize scheduler with timezone support
        jobstores = {"default": MemoryJobStore()}
        executors = {"default": AsyncIOExecutor()}
        job_defaults = {
            "coalesce": True,
            "max_instances": 1,
            "misfire_grace_time": 300,
        }

        logger.debug(f"Job defaults: {job_defaults}")

        self.scheduler = AsyncIOScheduler(
            jobstores=jobstores,
            executors=executors,
            job_defaults=job_defaults,
            timezone=initial_timezone,  # Use detected timezone
        )

        logger.info(f"Scheduler initialized with timezone: {initial_timezone}")
        logger.info("=" * 60)

    def _get_timezone(self) -> str:
        """
        Get timezone from ENV (if Docker) or config
        Priority:
        1. Environment variable TZ (only if IS_DOCKER is True)
        2. Config file timezone setting
        3. Default: Europe/Berlin
        """
        with self._lock:
            if self._cached_timezone:
                return self._cached_timezone

            logger.debug("Determining timezone...")

            if IS_DOCKER:
                env_tz = os.environ.get("TZ")
                if env_tz:
                    logger.info(f"Using timezone from ENV (Docker): {env_tz}")
                    self._cached_timezone = env_tz
                    return env_tz

            config = self.load_config()
            config_tz = config.get("timezone")
            if config_tz:
                logger.info(f"Using timezone from config: {config_tz}")
                self._cached_timezone = config_tz
                return config_tz

            default_tz = "Europe/Berlin"
            logger.info(f"Using default timezone: {default_tz}")
            self._cached_timezone = default_tz
            return default_tz

    def load_config(self) -> Dict:
        """Load scheduler configuration from JSON file (Thread-safe)"""
        with self._lock:
            default_config = {
                "enabled": False,
                "schedules": [],
                "timezone": "Europe/Berlin",
                "skip_if_running": True,
                "last_run": None,
                "next_run": None,
            }

            if not self.config_path.exists():
                self.save_config(default_config)
                return default_config

            try:
                with open(self.config_path, "r", encoding="utf-8") as f:
                    config = json.load(f)
                return {**default_config, **config}
            except Exception as e:
                logger.error(f"Error loading scheduler config: {e}")
                return default_config

    def save_config(self, config: Dict) -> bool:
        """Save scheduler configuration to JSON file (Thread-safe)"""
        with self._lock:
            try:
                with open(self.config_path, "w", encoding="utf-8") as f:
                    json.dump(config, f, indent=2, ensure_ascii=False)
                return True
            except Exception as e:
                logger.error(f"Error saving scheduler config: {e}")
                return False

    def update_config(self, updates: Dict) -> Dict:
        """Update specific config values (Thread-safe)"""
        with self._lock:
            if "timezone" in updates:
                self._cached_timezone = None

            config = self.load_config()
            config.update(updates)
            self.save_config(config)

            if "timezone" in updates and self.scheduler:
                self.scheduler.configure(timezone=updates["timezone"])
                if config.get("schedules"):
                    self.update_next_run_from_schedules()

            return config

    def _is_posterizarr_actually_running(self) -> bool:
        """Check if Posterizarr is actually running by checking for PowerShell processes"""
        if not PSUTIL_AVAILABLE:
            return True

        import psutil

        try:
            for proc in psutil.process_iter(["pid", "name", "cmdline"]):
                try:
                    cmdline = proc.info.get("cmdline")
                    if cmdline:
                        cmdline_str = " ".join(cmdline).lower()
                        if (
                            "pwsh" in cmdline_str or "powershell" in cmdline_str
                        ) and "posterizarr.ps1" in cmdline_str:
                            return True
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            return False
        except Exception as e:
            logger.error(f"Error checking for running processes: {e}")
            return True

    async def run_script(self, mode: str = "normal", force_run: bool = False):
        """Execute Posterizarr script in normal mode (non-blocking)"""
        with self._lock:
            config = self.load_config()
            if not force_run and config.get("skip_if_running", True) and self.is_running:
                logger.warning("Script is already running, skipping scheduled execution")
                return

            running_file = self.base_dir / "temp" / "Posterizarr.Running"
            if not force_run and running_file.exists():
                if self._is_posterizarr_actually_running():
                    logger.warning("Posterizarr process is running, cannot start another instance")
                    return
                else:
                    try:
                        running_file.unlink()
                    except Exception as e:
                        logger.error(f"Failed to delete stale running file: {e}")
                        return

            self.is_running = True
            config["last_run"] = datetime.now().isoformat()
            self.save_config(config)

        try:
            if platform.system() == "Windows":
                ps_command = "pwsh"
                try:
                    subprocess.run([ps_command, "-v"], capture_output=True, check=True)
                except (subprocess.CalledProcessError, FileNotFoundError):
                    ps_command = "powershell"
            else:
                ps_command = "pwsh"

            mode_switches = {
                "normal": ["-UISchedule"],
                "syncjelly": ["-UISchedule", "-SyncJelly"],
                "syncemby": ["-UISchedule", "-SyncEmby"],
                "backup": ["-UISchedule", "-Backup"]
            }

            switches = mode_switches.get(mode.lower(), ["-UISchedule"])
            command = [ps_command, "-File", str(self.script_path)] + switches

            logger.info(f"Executing scheduled run ({mode}): {' '.join(command)}")

            def run_in_thread():
                try:
                    process = subprocess.Popen(command, cwd=str(self.base_dir))
                    with self._lock:
                        self.current_process = process
                    return process.wait()
                except Exception as e:
                    logger.error(f"Error in subprocess thread: {e}")
                    return -1

            loop = asyncio.get_event_loop()
            returncode = await loop.run_in_executor(None, run_in_thread)
            logger.info(f"Scheduled run finished with return code: {returncode}")

        except Exception as e:
            logger.error(f"Error during scheduled script execution: {e}", exc_info=True)
        finally:
            with self._lock:
                self.is_running = False
                self.current_process = None
                self.update_next_run()

    def parse_schedule_time(self, time_str: str) -> tuple:
        """Parse HH:MM string into (hour, minute)"""
        try:
            parts = time_str.split(":")
            return int(parts[0]), int(parts[1])
        except Exception:
            return None, None

    def apply_schedules(self):
        """Apply all configured schedules to the scheduler (Thread-safe)"""
        with self._lock:
            config = self.load_config()

            if self.scheduler.running:
                self.scheduler.remove_all_jobs()

            if not config.get("enabled", False):
                return

            schedules = config.get("schedules", [])
            timezone = self._get_timezone()

            for idx, schedule in enumerate(schedules):
                mode = schedule.get("mode", "normal")
                frequency = schedule.get("frequency", "daily")
                job_id = f"posterizarr_{mode}_{idx}"

                # --- NEW INTERVAL LOGIC ---
                if frequency == "interval":
                    ival = int(schedule.get("interval_value", 1))
                    iunit = schedule.get("interval_unit", "hours")

                    trigger_args = {iunit: ival, "timezone": timezone}
                    trigger = IntervalTrigger(**trigger_args)
                    job_name = f"Posterizarr {mode.title()} (Every {ival} {iunit})"

                # --- EXISTING CRON LOGIC ---
                else:
                    time_str = schedule.get("time", "00:00")
                    hour, minute = self.parse_schedule_time(time_str)
                    if hour is None: continue

                    cron_kwargs = {
                        "hour": hour,
                        "minute": minute,
                        "timezone": timezone,
                        "month": schedule.get("month", "*"),
                        "day": schedule.get("day", "*") if frequency != "weekly" else "*",
                        "day_of_week": schedule.get("day_of_week", "*") if frequency != "daily" else "*"
                    }

                    # Refine logic for clean triggers
                    if frequency == "daily":
                        cron_kwargs.update({"day": "*", "month": "*", "day_of_week": "*"})
                    elif frequency == "weekly":
                        cron_kwargs.update({"day": "*", "month": "*"})

                    trigger = CronTrigger(**cron_kwargs)

                    # Enhanced display name for multi-day support
                    detail = f" ({frequency.title()})" if frequency != "daily" else ""
                    job_name = f"Posterizarr {mode.title()}{detail} @ {time_str}"

                self.scheduler.add_job(
                    self.run_script,
                    trigger=trigger,
                    id=job_id,
                    name=job_name,
                    args=[mode],
                    replace_existing=True,
                )
                logger.info(f"Added job: {job_name}")

            self.update_next_run()

    def update_next_run(self):
        """Update next_run timestamp in config (Thread-safe)"""
        with self._lock:
            try:
                jobs = self.scheduler.get_jobs()
                next_runs = [j.next_run_time for j in jobs if j.next_run_time]
                if next_runs:
                    next_run = min(next_runs)
                    config = self.load_config()
                    config["next_run"] = next_run.isoformat()
                    self.save_config(config)
            except Exception as e:
                logger.error(f"Error updating next_run: {e}")

    def start(self):
        """Start the scheduler (Thread-safe)"""
        with self._lock:
            config = self.load_config()
            if not config.get("enabled", False):
                return
            if not self.scheduler.running:
                self.scheduler.configure(timezone=self._get_timezone())
                self.apply_schedules()
                self.scheduler.start()
                self._scheduler_initialized = True

    def stop(self):
        """Stop the scheduler (Thread-safe)"""
        with self._lock:
            if self.scheduler.running:
                self.scheduler.shutdown(wait=False)
                config = self.load_config()
                config["next_run"] = None
                self.save_config(config)

    def restart(self):
        """Restart the scheduler (Thread-safe)"""
        with self._lock:
            self.stop()
            self.start()

    def get_status(self) -> Dict:
        """Get current scheduler status (Thread-safe)"""
        with self._lock:
            config = self.load_config()
            jobs = self.scheduler.get_jobs() if self.scheduler.running else []
            job_info = [{"id": j.id, "name": j.name, "next_run": j.next_run_time.isoformat() if j.next_run_time else None} for j in jobs]
            return {
                "enabled": config.get("enabled", False),
                "running": self.scheduler.running,
                "is_executing": self.is_running,
                "schedules": config.get("schedules", []),
                "timezone": self._get_timezone(),
                "last_run": config.get("last_run"),
                "next_run": config.get("next_run"),
                "active_jobs": job_info,
            }

    def calculate_next_run_time(self, schedule: Dict) -> Optional[str]:
        """Calculate next run for a schedule without starting scheduler"""
        with self._lock:
            timezone_str = self._get_timezone()
            tz = pytz.timezone(timezone_str)
            now = datetime.now(tz)

            frequency = schedule.get("frequency", "daily")

            if frequency == "interval":
                ival = int(schedule.get("interval_value", 1))
                iunit = schedule.get("interval_unit", "hours")
                trigger = IntervalTrigger(**{iunit: ival, "timezone": timezone_str})
            else:
                hour, minute = self.parse_schedule_time(schedule.get("time", "00:00"))
                if hour is None: return None
                cron_kwargs = {
                    "hour": hour, "minute": minute, "timezone": timezone_str,
                    "month": schedule.get("month", "*"),
                    "day": schedule.get("day", "*") if frequency != "weekly" else "*",
                    "day_of_week": schedule.get("day_of_week", "*") if frequency != "daily" else "*"
                }
                trigger = CronTrigger(**cron_kwargs)

            next_fire = trigger.get_next_fire_time(None, now)
            return next_fire.isoformat() if next_fire else None

    def update_next_run_from_schedules(self):
        """Update next_run in config based on all schedules"""
        with self._lock:
            config = self.load_config()
            schedules = config.get("schedules", [])
            if not schedules:
                config["next_run"] = None
                self.save_config(config)
                return

            next_runs = [self.calculate_next_run_time(s) for s in schedules]
            valid_runs = [r for r in next_runs if r]
            if valid_runs:
                config["next_run"] = min(valid_runs)
                self.save_config(config)

    def add_schedule(self, time_str: str, description: str = "", mode: str = "normal",
                     frequency: str = "daily", day_of_week: str = "*",
                     day: Union[int, str] = "*", month: str = "*",
                     interval_value: int = 1, interval_unit: str = "hours") -> bool:
        """Add a new schedule (Thread-safe)"""
        with self._lock:
            config = self.load_config()
            schedules = config.get("schedules", [])

            new_entry = {
                "time": time_str,
                "description": description,
                "mode": mode,
                "frequency": frequency,
                "day_of_week": day_of_week,
                "day": day,
                "month": month,
                "interval_value": interval_value,
                "interval_unit": interval_unit
            }

            schedules.append(new_entry)
            config["schedules"] = schedules
            self.save_config(config)

            if config.get("enabled", False) and self.scheduler.running:
                self.apply_schedules()
            else:
                self.update_next_run_from_schedules()
            return True

    def remove_schedule(self, time_str: str) -> bool:
        """Remove a schedule by time"""
        with self._lock:
            config = self.load_config()
            schedules = config.get("schedules", [])
            new_schedules = [s for s in schedules if s.get("time") != time_str]
            if len(new_schedules) == len(schedules): return False

            config["schedules"] = new_schedules
            if not new_schedules: config["next_run"] = None
            self.save_config(config)

            if config.get("enabled", False) and self.scheduler.running:
                self.apply_schedules()
            else:
                self.update_next_run_from_schedules()
            return True

    def clear_schedules(self) -> bool:
        """Remove all schedules"""
        with self._lock:
            config = self.load_config()
            config["schedules"] = []
            config["next_run"] = None
            self.save_config(config)
            if config.get("enabled", False) and self.scheduler.running:
                self.apply_schedules()
            return True