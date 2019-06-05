import os
import subprocess          
import sys                 

from rosidl_cmake import convert_camel_case_to_lower_case_underscore
from rosidl_cmake import expand_template
from rosidl_cmake import get_newest_modification_time
from rosidl_parser import parse_message_file
from rosidl_parser import parse_service_file
from rosidl_parser import validate_field_types


def parse_ros_interface_files(pkg_name, ros_interface_files):
    message_specs = []     
    service_specs = []     
    for idl_file in ros_interface_files:
        extension = os.path.splitext(idl_file)[1] 
        if extension == '.msg':
            message_spec = parse_message_file(pkg_name, idl_file)
            message_specs.append((idl_file, message_spec))
        elif extension == '.srv':       
            service_spec = parse_service_file(pkg_name, idl_file)
            service_specs.append((idl_file, service_spec))
    return (message_specs, service_specs)


def generate_dds_coredds_cpp(
        pkg_name, dds_interface_files, dds_interface_base_path, deps,
        output_basepath, idl_pp, message_specs, service_specs):

    include_dirs = [dds_interface_base_path]
    for dep in deps:
        # Only take the first : for separation, as Windows follows with a C:\
        dep_parts = dep.split(':', 1)
        assert len(dep_parts) == 2, "The dependency '%s' must contain a double colon" % dep
        idl_path = dep_parts[1]
        idl_base_path = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.normpath(idl_path))))
        if idl_base_path not in include_dirs:
            include_dirs.append(idl_base_path)
  
    for index, idl_file in enumerate(dds_interface_files):
        assert os.path.exists(idl_file), 'Could not find IDL file: ' + idl_file

        # get two level of parent folders for idl file
        folder = os.path.dirname(idl_file)
        parent_folder = os.path.dirname(folder)
        output_path = os.path.join(     
            output_basepath,
            os.path.basename(parent_folder),
            os.path.basename(folder))       
        try:               
            os.makedirs(output_path)    
        except FileExistsError:
            pass           

        _modify(idl_file, pkg_name, os.path.splitext(os.path.basename(idl_file))[0], (str(os.path.basename(parent_folder)) == "srv"))

        cmd = [idl_pp]     
        for include_dir in include_dirs:
            cmd += ['-I', include_dir]  
        cmd += [           
            'c',
            '--case-sensitive',
            idl_file,
            output_path
        ]

        msg_name = os.path.splitext(os.path.basename(idl_file))[0]
        count = 1
        max_count = 5
        
        while True:
            subprocess.check_call(cmd)  

            # fail safe if the generator does not work as expected
            any_missing = False
            for suffix in ['TypeSupport.h', '.h', 'TypeSupport.c']:
                add_path = ''
                temp_output_path = ''
                if suffix[-1] == 'h':
                    add_path = '/include/' + pkg_name + '/' + os.path.basename(parent_folder) + '/' + 'dds_/'
                else:
                    add_path = '/src/' + pkg_name + '_' + os.path.basename(parent_folder) + '_' + 'dds__'
                temp_output_path = output_path + add_path
                filename = temp_output_path + msg_name + suffix
                if not os.path.exists(filename):
                    any_missing = True          
                    break
            if not any_missing:
                break
            print("'%s' failed to generate the expected files for '%s/%s'" %
                  (idl_pp, pkg_name, msg_name), file=sys.stderr)
            if count < max_count:
                count += 1
                print('Running code generator again (retry %d of %d)...' %
                      (count, max_count), file=sys.stderr)
                continue
            raise RuntimeError('failed to generate the expected files')

    return 0

def _modify(filename, pkg_name, msg_name, is_srv):
    modified = False
    with open(filename, 'r') as h:
        lines = h.read().split('\n')
    if is_srv == True:
        modified = add_seq_number(lines)
    #modified = relative_to_absolute(pkg_name, msg_name, lines)
    if modified:
        with open(filename, 'w') as h:
            h.write('\n'.join(lines))

def add_seq_number(lines):
    for i, line in enumerate(lines):
        if line.startswith('  long long coredds__sequence_number_;'):
            break
        if line.startswith('};'):
            assert i >= 2, 'unexpected end of struct declaration'
            lines.insert(i - 1, '  long long coredds__sequence_number_;')
            lines.insert(i, '  unsigned long long coredds__client_guid_0_;')
            lines.insert(i + 1, '  unsigned long long coredds__client_guid_1_;')
            break
    return lines

def relative_to_absolute(pkg_name, msg_name, lines): # TODO: remove this
    for i, line in enumerate(lines):
        if line.startswith('#include "/'):
            continue
        if line.startswith('#include "'):
            ref_path = line[10:-1]
            ref_pkg_name = ref_path.split('/')[0]
            lines[i] = line.replace('#include "', '#include "/home/junho/ros2_ws/build/' + ref_pkg_name + '/rosidl_generator_dds_idl/')
    return lines

def generate_cpp(args, message_specs, service_specs, known_msg_types):
    template_dir = args['template_dir']
    mapping_msgs = {
        os.path.join(template_dir, 'msg__rosidl_typesupport_coredds_cpp.hpp.em'):
        '%s__rosidl_typesupport_coredds_cpp.hpp',
        os.path.join(template_dir, 'msg__type_support.cpp.em'):
        '%s__type_support.cpp',
    }
    mapping_srvs = {
        os.path.join(template_dir, 'srv__rosidl_typesupport_coredds_cpp.hpp.em'):
        '%s__rosidl_typesupport_coredds_cpp.hpp',
        os.path.join(template_dir, 'srv__type_support.cpp.em'):
        '%s__type_support.cpp',
    }

    for template_file in mapping_msgs.keys():
        assert os.path.exists(template_file), 'Could not find template: ' + template_file
    for template_file in mapping_srvs.keys():
        assert os.path.exists(template_file), 'Could not find template: ' + template_file

    functions = {
        'get_header_filename_from_msg_name': convert_camel_case_to_lower_case_underscore,
    }
    # generate_dds_coredds_cpp() and therefore the make target depend on the additional files
    # therefore they must be listed here even if the generated type support files are independent
    latest_target_timestamp = get_newest_modification_time(
        args['target_dependencies'] + args.get('additional_files', []))

    for idl_file, spec in message_specs:
        validate_field_types(spec, known_msg_types)
        subfolder = os.path.basename(os.path.dirname(idl_file))
        for template_file, generated_filename in mapping_msgs.items():
            generated_file = os.path.join(args['output_dir'], subfolder)
            if generated_filename.endswith('.cpp') or generated_filename.endswith('.c'):
                generated_file = os.path.join(generated_file, 'dds_coredds')
            generated_file = os.path.join(
                generated_file, generated_filename %
                convert_camel_case_to_lower_case_underscore(spec.base_type.type))

            data = {'spec': spec, 'subfolder': subfolder}
            data.update(functions)
            expand_template(
                template_file, data, generated_file,
                minimum_timestamp=latest_target_timestamp)

    for idl_file, spec in service_specs:
        validate_field_types(spec, known_msg_types)
        subfolder = os.path.basename(os.path.dirname(idl_file))
        for template_file, generated_filename in mapping_srvs.items():
            generated_file = os.path.join(args['output_dir'], subfolder)
            if generated_filename.endswith('.cpp') or generated_filename.endswith('.c'):
                generated_file = os.path.join(generated_file, 'dds_coredds')
            generated_file = os.path.join(
                generated_file, generated_filename %
                convert_camel_case_to_lower_case_underscore(spec.srv_name))

            data = {'spec': spec, 'subfolder': subfolder}
            data.update(functions)
            expand_template(
                template_file, data, generated_file,
                minimum_timestamp=latest_target_timestamp)

    return 0