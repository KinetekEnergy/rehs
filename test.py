# # from textual.app import App, ComposeResult
# # from textual.widgets import Input, Label, Button, Static
# # from textual.containers import Vertical, Horizontal
# # from textual.message import Message
# # from textual.widgets import Header


# # class MyFormSubmitted(Message):
# #     def __init__(self, sender, name: str, email: str):
# #         self.name = name
# #         self.email = email
# #         super().__init__(sender)


# # class MyForm(Static):
# #     def compose(self) -> ComposeResult:
# #         # sbatch --partition=debug --job-name=bert-test --account=ddp324 --time=00:05:00 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --mem=1G --output=%x.o%j.%N mlcr process,mlperf,accuracy,_squad --result_dir=bert-results/
# #         yield Input(placeholder="Partition name")

# #         yield Input(placeholder="Enter your name", id="name")
# #         yield Input(placeholder="Enter your email", id="email")
# #         yield Button("Submit", id="submit")


# #     def on_button_pressed(self, event: Button.Pressed) -> None:
# #         name_input = self.query_one("#name", Input)
# #         email_input = self.query_one("#email", Input)
# #         self.post_message(MyFormSubmitted(self, name_input.value, email_input.value))


# # class MyFormApp(App):
# #     CSS = """
# #     #title {
# #         text-align: center;
# #         height: auto;
# #         margin-bottom: 1;
# #     }
# #     Input {
# #         margin: 1;
# #         width: 80%;
# #     }
# #     Button {
# #         width: 20;
# #         margin: 1;
# #     }
# #     """

# #     def compose(self) -> ComposeResult:
# #         yield Vertical(MyForm(), id="form_container")

# #     def on_my_form_submitted(self, message: MyFormSubmitted) -> None:
# #         self.exit(f"Form submitted!\nName: {message.name}\nEmail: {message.email}")


# # if __name__ == "__main__":
# #     MyFormApp().run()

# from textual.app import App, ComposeResult
# from textual.widgets import Footer, Header, OptionList, Input


# class OptionListApp(App[None]):
#     CSS_PATH = "option_list.tcss"

#     def compose(self) -> ComposeResult:
#         yield Header()
#         yield OptionList(
#             "Aerilon",
#             "Aquaria",
#             "Canceron",
#             "Caprica",
#             "Gemenon",
#             "Leonis",
#             "Libran",
#             "Picon",
#             "Sagittaron",
#             "Scorpia",
#             "Tauron",
#             "Virgon",
#         )
#         yield Input(placeholder="Enter your name", id="name")
#         yield Footer()


# if __name__ == "__main__":
#     OptionListApp().run()

#!/usr/bin/env python3

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import (
    Header,
    Footer,
    Button,
    Input,
    Select,
    Static,
    Checkbox,
    RadioButton,
    RadioSet,
    Label,
)
from textual.validation import Function
import re


def validate_no_spaces(value: str) -> bool:
    """Validate that the input contains no spaces."""
    return " " not in value


def validate_time_format(value: str) -> bool:
    """Validate time format (HH:MM:SS)."""
    pattern = r"^\d{2}:\d{2}:\d{2}$"
    return bool(re.match(pattern, value))


class JobSubmitForm(App):
    """A Textual app for submitting batch jobs."""

    CSS = """
    .form-container {
        padding: 1;
        margin: 1;
        border: solid $primary;
        border-title-align: center;
    }
    
    .form-row {
        height: auto;
        margin: 1 0;
    }
    
    .form-label {
        width: 20;
        content-align: right middle;
        padding-right: 1;
    }
    
    .form-input {
        width: 1fr;
    }
    
    .memory-row {
        align: left middle;
    }
    
    .submit-buttons {
        align: center middle;
        margin: 2 0;
    }
    
    .checkbox-group {
        margin: 1 0;
    }
    
    .radio-group {
        margin: 1 0;
    }
    
    Input {
        margin: 0 1;
    }
    
    Select {
        margin: 0 1;
    }
    
    Button {
        margin: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        """Create child widgets for the app."""
        yield Header()

        with Container(classes="form-container"):
            yield Static("Submit a Job", classes="form-title")

            # Partition dropdown
            with Horizontal(classes="form-row"):
                yield Label("Partition:", classes="form-label")
                yield Select(
                    [("debug", "debug"), ("gpu-shared", "gpu-shared")],
                    prompt="Select partition",
                    value="debug",
                    id="partition",
                    classes="form-input",
                )

            # Job Name
            with Horizontal(classes="form-row"):
                yield Label("Job Name:", classes="form-label")
                yield Input(
                    placeholder="Enter job name (no spaces)",
                    id="job_name",
                    validators=[
                        Function(validate_no_spaces, "Job name cannot contain spaces")
                    ],
                    classes="form-input",
                )

            # Account
            with Horizontal(classes="form-row"):
                yield Label("Account:", classes="form-label")
                yield Input(
                    placeholder="Enter account name (no spaces)",
                    id="account",
                    validators=[
                        Function(
                            validate_no_spaces, "Account name cannot contain spaces"
                        )
                    ],
                    classes="form-input",
                )

            # Time
            with Horizontal(classes="form-row"):
                yield Label("Time:", classes="form-label")
                yield Input(
                    placeholder="HH:MM:SS (e.g., 00:05:00)",
                    id="time",
                    validators=[
                        Function(
                            validate_time_format, "Time must be in HH:MM:SS format"
                        )
                    ],
                    classes="form-input",
                )

            # Nodes
            with Horizontal(classes="form-row"):
                yield Label("Nodes:", classes="form-label")
                yield Input(
                    placeholder="Number of nodes",
                    id="nodes",
                    type="integer",
                    classes="form-input",
                )

            # Tasks per node
            with Horizontal(classes="form-row"):
                yield Label("Tasks per node:", classes="form-label")
                yield Input(
                    placeholder="Tasks per node",
                    id="tasks_per_node",
                    type="integer",
                    classes="form-input",
                )

            # CPUs per task
            with Horizontal(classes="form-row"):
                yield Label("CPUs per task:", classes="form-label")
                yield Input(
                    placeholder="CPUs per task",
                    id="cpus_per_task",
                    type="integer",
                    classes="form-input",
                )

            # Memory
            with Horizontal(classes="form-row"):
                yield Label("Memory:", classes="form-label")
                with Horizontal(classes="memory-row form-input"):
                    yield Input(
                        placeholder="Amount", id="memory_amount", type="integer"
                    )
                    yield Select(
                        [("GB", "GB"), ("MB", "MB")], value="GB", id="memory_unit"
                    )

            # Output
            with Horizontal(classes="form-row"):
                yield Label("Output:", classes="form-label")
                yield Input(
                    placeholder="Output format (e.g., %x.o%j.%N)",
                    id="output",
                    classes="form-input",
                )

            # Custom command
            with Horizontal(classes="form-row"):
                yield Label("Custom command:", classes="form-label")
                yield Input(
                    placeholder="Enter custom command",
                    id="custom_command",
                    classes="form-input",
                )

            # Result directory
            with Horizontal(classes="form-row"):
                yield Label("Result directory:", classes="form-label")
                yield Input(
                    placeholder="Path to result directory",
                    id="result_dir",
                    classes="form-input",
                )

            # Job runner options (checkboxes)
            with Vertical(classes="checkbox-group"):
                yield Label("Job runner options:")
                yield Checkbox("Run job immediately", id="run_immediately")
                yield Checkbox("Create as a script", id="create_script")

            # Viewing options (radio buttons)
            with Vertical(classes="radio-group"):
                yield Label("Viewing options:")
                with RadioSet(id="viewing_options"):
                    yield RadioButton("Run as a batch job", value=True, id="batch_job")
                    yield RadioButton("Run here", id="run_here")

            # Submit buttons
            with Horizontal(classes="submit-buttons"):
                yield Button("Generate Command", variant="primary", id="generate")
                yield Button("Submit Job", variant="success", id="submit")
                yield Button("Clear Form", variant="default", id="clear")

        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press events."""
        if event.button.id == "generate":
            self.generate_command()
        elif event.button.id == "submit":
            self.submit_job()
        elif event.button.id == "clear":
            self.clear_form()

    def generate_command(self) -> None:
        """Generate the sbatch command based on form inputs."""
        try:
            # Get form values
            partition = self.query_one("#partition", Select).value
            job_name = self.query_one("#job_name", Input).value
            account = self.query_one("#account", Input).value
            time = self.query_one("#time", Input).value
            nodes = self.query_one("#nodes", Input).value
            tasks_per_node = self.query_one("#tasks_per_node", Input).value
            cpus_per_task = self.query_one("#cpus_per_task", Input).value
            memory_amount = self.query_one("#memory_amount", Input).value
            memory_unit = self.query_one("#memory_unit", Select).value
            output = self.query_one("#output", Input).value
            custom_command = self.query_one("#custom_command", Input).value
            result_dir = self.query_one("#result_dir", Input).value

            # Build the command
            command_parts = ["sbatch"]

            if partition:
                command_parts.append(f"--partition={partition}")
            if job_name:
                command_parts.append(f"--job-name={job_name}")
            if account:
                command_parts.append(f"--account={account}")
            if time:
                command_parts.append(f"--time={time}")
            if nodes:
                command_parts.append(f"--nodes={nodes}")
            if tasks_per_node:
                command_parts.append(f"--ntasks-per-node={tasks_per_node}")
            if cpus_per_task:
                command_parts.append(f"--cpus-per-task={cpus_per_task}")
            if memory_amount and memory_unit:
                command_parts.append(f"--mem={memory_amount}{memory_unit}")
            if output:
                command_parts.append(f"--output={output}")

            if custom_command:
                command_parts.append(custom_command)

            if result_dir:
                command_parts.append(f"--result_dir={result_dir}")

            full_command = " ".join(command_parts)

            # Display the command (you could also save it or copy to clipboard)
            self.notify(f"Generated command: {full_command}", title="Command Generated")

        except Exception as e:
            self.notify(f"Error generating command: {str(e)}", severity="error")

    def submit_job(self) -> None:
        """Submit the job (placeholder for actual submission logic)."""
        # Check job runner options
        run_immediately = self.query_one("#run_immediately", Checkbox).value
        create_script = self.query_one("#create_script", Checkbox).value

        # Check viewing options
        viewing_options = self.query_one("#viewing_options", RadioSet).pressed_button
        viewing_mode = viewing_options.id if viewing_options else "batch_job"

        if run_immediately:
            self.notify("Job submitted for immediate execution", title="Job Submitted")
        elif create_script:
            self.notify("Job script created", title="Script Created")
        else:
            self.notify("Please select a job runner option", severity="warning")

    def clear_form(self) -> None:
        """Clear all form inputs."""
        # Clear text inputs
        for input_id in [
            "job_name",
            "account",
            "time",
            "nodes",
            "tasks_per_node",
            "cpus_per_task",
            "memory_amount",
            "output",
            "custom_command",
            "result_dir",
        ]:
            self.query_one(f"#{input_id}", Input).value = ""

        # Reset selects to default
        self.query_one("#partition", Select).value = "debug"
        self.query_one("#memory_unit", Select).value = "GB"

        # Clear checkboxes
        self.query_one("#run_immediately", Checkbox).value = False
        self.query_one("#create_script", Checkbox).value = False

        # Reset radio buttons
        self.query_one("#batch_job", RadioButton).value = True

        self.notify("Form cleared", title="Form Reset")


if __name__ == "__main__":
    app = JobSubmitForm()
    app.run()
