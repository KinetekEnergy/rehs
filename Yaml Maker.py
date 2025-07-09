import npyscreen
import yaml
import os


# class CondaPackageEntry(npyscreen.MultiLineEdit):
#     """Custom widget for entering conda packages with versions"""

#     def __init__(self, *args, **kwargs):
#         super().__init__(*args, **kwargs)
#         self.value = "# Enter packages one per line\n# Format: package_name=version or just package_name\n# Example: python=3.9.23\n# Example: pandas=2.2.3\n# Example: pip\n"


# class PipPackageEntry(npyscreen.MultiLineEdit):
#     """Custom widget for entering pip packages with versions"""

#     def __init__(self, *args, **kwargs):
#         super().__init__(*args, **kwargs)
#         self.value = "# Enter pip packages one per line\n# Format: package_name==version or just package_name\n# Example: diffusers==0.30.3\n# Example: transformers==4.45.2\n"


# class CondaConfiguration(npyscreen.Form):
#     def afterEditing(self):
#         self.parentApp.setNextForm("PREVIEW")

#     def create(self):
#         # Environment name
#         self.envName = self.add(
#             npyscreen.TitleText, name="Environment Name:", value="my-conda-env"
#         )

#         # Spacing
#         self.nextrely += 1

#         # Conda channels selection
#         self.add(npyscreen.FixedText, value="Select Standard Channels:", editable=False)
#         self.channels = self.add(
#             npyscreen.TitleMultiSelect,
#             scroll_exit=True,
#             max_height=4,
#             name="Standard Channels:",
#             values=[
#                 "conda-forge",
#                 "nvidia",
#                 "pytorch",
#                 "defaults",
#                 "bioconda",
#                 "intel",
#             ],
#         )

#         # Custom channels
#         self.customChannels = self.add(
#             npyscreen.TitleText, name="Custom Channels (comma-separated):", value=""
#         )

#         # Spacing
#         self.nextrely += 1

#         # Common dependencies selection
#         self.add(
#             npyscreen.FixedText, value="Select Common Dependencies:", editable=False
#         )
#         self.commonDeps = self.add(
#             npyscreen.TitleMultiSelect,
#             scroll_exit=True,
#             max_height=5,
#             name="Common Dependencies:",
#             values=[
#                 "pip",
#                 "python",
#                 "cmake",
#                 "clang",
#                 "numpy",
#                 "pandas",
#                 "scipy",
#                 "opencv",
#             ],
#         )

#         # Python version
#         self.pythonVersion = self.add(
#             npyscreen.TitleSelectOne,
#             scroll_exit=True,
#             max_height=4,
#             name="Python Version:",
#             values=["3.8", "3.9", "3.10", "3.11", "3.12"],
#         )

#         # Spacing
#         self.nextrely += 1

#         # Custom conda packages
#         self.add(
#             npyscreen.FixedText,
#             value="Custom Conda Packages (with versions):",
#             editable=False,
#         )
#         self.condaPackages = self.add(
#             CondaPackageEntry, name="Conda Packages:", max_height=6
#         )

#         # Spacing
#         self.nextrely += 1

#         # Pip packages
#         self.add(
#             npyscreen.FixedText, value="Pip Packages (with versions):", editable=False
#         )
#         self.pipPackages = self.add(PipPackageEntry, name="Pip Packages:", max_height=6)


# class PreviewForm(npyscreen.Form):
#     def afterEditing(self):
#         self.parentApp.setNextForm("SAVE")

#     def create(self):
#         self.add(npyscreen.FixedText, value="YAML Preview:", editable=False)
#         self.preview = self.add(
#             npyscreen.MultiLineEdit,
#             name="Generated YAML:",
#             max_height=-3,
#             editable=False,
#         )

#     def beforeEditing(self):
#         # Generate YAML content
#         yaml_content = self.generate_yaml()
#         self.preview.value = yaml_content

#     def generate_yaml(self):
#         conda_form = self.parentApp.getForm("MAIN")

#         # Start building the YAML structure
#         yaml_data = {}

#         # Environment name
#         env_name = conda_form.envName.value.strip()
#         if env_name:
#             yaml_data["name"] = env_name

#         # Channels
#         channels = []

#         # Add selected standard channels
#         selected_channels = conda_form.channels.get_selected_objects()
#         channels.extend(selected_channels)

#         # Add custom channels
#         custom_channels = conda_form.customChannels.value.strip()
#         if custom_channels:
#             custom_list = [
#                 ch.strip() for ch in custom_channels.split(",") if ch.strip()
#             ]
#             channels.extend(custom_list)

#         if channels:
#             yaml_data["channels"] = channels

#         # Dependencies
#         dependencies = []

#         # Add Python version if selected
#         if conda_form.pythonVersion.value is not None:
#             python_versions = conda_form.pythonVersion.values
#             selected_python = python_versions[conda_form.pythonVersion.value[0]]
#             dependencies.append(f"python={selected_python}")

#         # Add common dependencies
#         selected_common = conda_form.commonDeps.get_selected_objects()
#         dependencies.extend(selected_common)

#         # Add custom conda packages
#         conda_packages_text = conda_form.condaPackages.value
#         if conda_packages_text:
#             lines = conda_packages_text.split("\n")
#             for line in lines:
#                 line = line.strip()
#                 if line and not line.startswith("#"):
#                     dependencies.append(line)

#         # Add pip packages
#         pip_packages_text = conda_form.pipPackages.value
#         pip_packages = []
#         if pip_packages_text:
#             lines = pip_packages_text.split("\n")
#             for line in lines:
#                 line = line.strip()
#                 if line and not line.startswith("#"):
#                     pip_packages.append(line)

#         # If we have pip packages, add pip dependency and pip section
#         if pip_packages:
#             if "pip" not in dependencies:
#                 dependencies.append("pip")
#             dependencies.append({"pip": pip_packages})

#         if dependencies:
#             yaml_data["dependencies"] = dependencies

#         # Convert to YAML string
#         return yaml.dump(yaml_data, default_flow_style=False, sort_keys=False)


# class SaveForm(npyscreen.Form):
#     def afterEditing(self):
#         self.parentApp.setNextForm(None)

#     def create(self):
#         self.filename = self.add(
#             npyscreen.TitleFilename, name="Save YAML as:", value="environment.yml"
#         )
#         self.add(npyscreen.FixedText, value="", editable=False)
#         self.add(npyscreen.FixedText, value="Press OK to save and exit", editable=False)

#     def beforeEditing(self):
#         # Auto-generate filename based on environment name
#         conda_form = self.parentApp.getForm("MAIN")
#         env_name = conda_form.envName.value.strip()
#         if env_name:
#             self.filename.value = f"{env_name}.yml"

#     def afterEditing(self):
#         # Save the YAML file
#         preview_form = self.parentApp.getForm("PREVIEW")
#         yaml_content = preview_form.generate_yaml()

#         filename = self.filename.value.strip()
#         if filename:
#             try:
#                 with open(filename, "w") as f:
#                     f.write(yaml_content)
#                 npyscreen.notify_confirm(f"YAML saved successfully as: {filename}")
#             except Exception as e:
#                 npyscreen.notify_confirm(f"Error saving file: {str(e)}")

#         self.parentApp.setNextForm(None)


# class CondaYAMLCreator(npyscreen.NPSAppManaged):
#     def onStart(self):
#         self.addForm("MAIN", CondaConfiguration, name="Conda Environment Configuration")
#         self.addForm("PREVIEW", PreviewForm, name="YAML Preview")
#         self.addForm("SAVE", SaveForm, name="Save YAML File")


# if __name__ == "__main__":
#     app = CondaYAMLCreator()
#     app.run()
class ActionControllerSearch(npyscreen.ActionControllerSimple):
    def create(self):
        self.add_action("^/.*", self.set_search, True)

    def set_search(self, command_line, widget_proxy, live):
        self.parent.value.set_filter(command_line[1:])
        self.parent.wMain.values = self.parent.value.get()
        self.parent.wMain.display()


class FmSearchActive(npyscreen.FormMuttActiveTraditional):
    ACTION_CONTROLLER = ActionControllerSearch


class TestApp(npyscreen.NPSApp):
    def main(self):
        F = FmSearchActive()
        F.wStatus1.value = "Status Line "
        F.wStatus2.value = "Second Status Line "
        F.value.set_values([str(x) for x in range(500)])
        F.wMain.values = F.value.get()

        F.edit()


if __name__ == "__main__":
    App = TestApp()
    App.run()
