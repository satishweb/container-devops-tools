#!/usr/bin/env python3

import argparse
import sys
import time
import unittest

START_TIMEOUT = 120  # seconds to wait for the container to be usable
# The tools that have to be in the image.
TOOLS = ["jq", "terraform", "tflint", "terrascan", "kubectl", "helm"]


def wait_for_container(container, timeout=START_TIMEOUT):
    print("Waiting for the container to be usable...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        status = state.get("Status")
        if status in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container stopped before it was usable (status={status}).\n{logs}"
            )
        if status == "running":
            try:
                if container.exec_run("true").exit_code == 0:
                    print("The container is usable.")
                    return
            except Exception:
                pass
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(f"The container was not usable within {timeout}s.\n{logs}")
        time.sleep(2)


def run_tests(image_name):
    import docker

    class TestDevopsTools(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            cls.client = docker.from_env()
            cls.container = cls.client.containers.run(
                image_name,
                detach=True,
                command=["/bin/bash", "-c", "sleep 600"],
            )
            wait_for_container(cls.container)

        @classmethod
        def tearDownClass(cls):
            cls.container.stop()
            cls.container.remove()

        def test_runs_as_unprivileged_user(self):
            print("Running the user test...")
            result = self.container.exec_run(["id", "-u"])
            uid = result.output.decode().strip()
            self.assertNotEqual(uid, "0", "The container runs as root")
            print("User test passed.")

        def test_the_tools_are_there(self):
            print("Running the tools test...")
            for tool in TOOLS:
                result = self.container.exec_run(["sh", "-c", f"command -v {tool}"])
                self.assertEqual(result.exit_code, 0, f"The tool {tool} is not in the image")
            print("Tools test passed.")

    print(f"Starting the container from the image '{image_name}'...")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestDevopsTools)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the tests for the devops tools image.")
    parser.add_argument(
        "--image",
        type=str,
        default="satishweb/container-devops-tools:ci",
        help="The image that is tested",
    )
    args = parser.parse_args()

    run_tests(args.image)
