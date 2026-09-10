package foster_framework

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:bytes"
import zlib "core:compress/zlib"
import "core:strings"
import SDL "vendor:sdl3"
// core:os 与 core:path/filepath 分别经 storage_os_* 与 storage_path_* 平台层使用
// (两者在 js 目标不可用)

DialogResult :: struct {
	Files: []string,
	Cancelled: bool,
}

DialogCallback :: #type proc(result: DialogResult)
DialogCallbackSingleFile :: #type proc(file: string)

DialogFilter :: struct {
	Name: string,
	Pattern: string,
}

StorageContainer :: struct {
	Root: string,
	Writable: bool,
}

Storage :: StorageContainer

// Concrete storage implementations mirror Foster's storage backends while
// keeping the small StorageContainer value type usable by existing code.
DirectoryStorage :: struct {
	Container: StorageContainer,
}

RelativeStorage :: struct {
	Container: StorageContainer,
	Prefix: string,
}

ContentStorage :: struct {
	Container: StorageContainer,
}

ZipStorage :: struct {
	Container: StorageContainer,
	Entries: map[string][dynamic]u8,
}

FileSystem :: struct {
	App: ^App,
}

storage_join_path :: proc(container: ^StorageContainer, path: string) -> string {
	if container.Root == "" {
		return storage_path_clean(path)
	}
	if strings.trim_space(path) == "" {
		return container.Root
	}
	joined := storage_path_join({container.Root, path})
	return storage_path_clean(joined)
}

storage_exists :: proc(container: ^StorageContainer, path: string) -> bool {
	return storage_os_exists(storage_join_path(container, path))
}

storage_file_exists :: proc(container: ^StorageContainer, path: string) -> bool {
	full := storage_join_path(container, path)
	return storage_os_exists(full) && !storage_os_is_directory(full)
}

storage_directory_exists :: proc(container: ^StorageContainer, path: string) -> bool {
	return storage_os_is_directory(storage_join_path(container, path))
}

storage_enumerate_directory :: proc(container: ^StorageContainer, path: string, allocator := context.allocator) -> []string {
	return storage_os_enumerate(storage_join_path(container, path), allocator)
}

storage_create_directory :: proc(container: ^StorageContainer, path: string) -> bool {
	if !container.Writable {
		return false
	}
	return storage_os_make_directory_all(storage_join_path(container, path))
}

storage_remove :: proc(container: ^StorageContainer, path: string) -> bool {
	if !container.Writable {
		return false
	}
	return storage_os_remove(storage_join_path(container, path))
}

storage_read_all_bytes :: proc(container: ^StorageContainer, path: string, allocator := context.allocator) -> []byte {
	return storage_os_read_file(storage_join_path(container, path), allocator)
}

storage_read_all_text :: proc(container: ^StorageContainer, path: string, allocator := context.allocator) -> string {
	data := storage_read_all_bytes(container, path, allocator)
	if len(data) == 0 {
		return ""
	}
	return string(data)
}

storage_write_all_bytes :: proc(container: ^StorageContainer, path: string, data: []byte) -> bool {
	if !container.Writable {
		return false
	}
	full := storage_join_path(container, path)
	parent, _ := storage_path_split(full)
	if parent != "" {
		_ = storage_os_make_directory_all(parent)
	}
	return storage_os_write_file(full, data)
}

storage_write_all_text :: proc(container: ^StorageContainer, path, data: string) -> bool {
	return storage_write_all_bytes(container, path, transmute([]byte)data)
}

storage_dispose :: proc(container: ^StorageContainer) {
	_ = container
}

DialogRequestKind :: enum { OpenFiles, OpenFolder, SaveFile }
DialogRequest :: struct {
	Kind: DialogRequestKind,
	FilesCallback: DialogCallback,
	SingleCallback: DialogCallbackSingleFile,
}

storage_dialog_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: c.int) {
	context = runtime.default_context()
	request := cast(^DialogRequest)userdata
	if request == nil { return }
	files: [dynamic]string
	if filelist != nil {
		for i := 0; filelist[i] != nil; i += 1 { append(&files, string(filelist[i])) }
	}
	cancelled := len(files) == 0
	if request.Kind == .OpenFiles {
		if request.FilesCallback != nil { request.FilesCallback(DialogResult{Files = files[:], Cancelled = cancelled}) }
	} else {
		if request.SingleCallback != nil {
			path := ""
			if len(files) > 0 { path = files[0] }
			request.SingleCallback(path)
		}
	}
	delete(files)
	free(request)
	_ = filter
}

storage_dialog_filters :: proc(filters: []DialogFilter) -> [dynamic]SDL.DialogFileFilter {
	result: [dynamic]SDL.DialogFileFilter
	for filter in filters {
		append(&result, SDL.DialogFileFilter{name = to_cstring(filter.Name), pattern = to_cstring(filter.Pattern)})
	}
	return result
}

storage_dialog_properties :: proc(fs: ^FileSystem, title: string, filters: []DialogFilter, many: bool) -> SDL.PropertiesID {
	props := SDL.CreateProperties()
	if props == 0 { return 0 }
	_ = SDL.SetStringProperty(props, to_cstring(SDL.PROP_FILE_DIALOG_TITLE_STRING), to_cstring(title))
	if fs != nil && fs.App != nil && fs.App.Window.Handle != nil {
		_ = SDL.SetPointerProperty(props, to_cstring(SDL.PROP_FILE_DIALOG_WINDOW_POINTER), fs.App.Window.Handle)
	}
	if len(filters) > 0 {
		converted := storage_dialog_filters(filters)
		_ = SDL.SetPointerProperty(props, to_cstring(SDL.PROP_FILE_DIALOG_FILTERS_POINTER), raw_data(converted))
		_ = SDL.SetNumberProperty(props, to_cstring(SDL.PROP_FILE_DIALOG_NFILTERS_NUMBER), i64(len(converted)))
	}
	_ = SDL.SetBooleanProperty(props, to_cstring(SDL.PROP_FILE_DIALOG_MANY_BOOLEAN), many)
	return props
}

directory_storage_init :: proc(storage: ^DirectoryStorage, root: string, writable := true) {
	storage.Container = StorageContainer{Root = root, Writable = writable}
}

directory_storage_as_container :: proc(storage: ^DirectoryStorage) -> ^StorageContainer {
	if storage == nil { return nil }
	return &storage.Container
}

relative_storage_init :: proc(storage: ^RelativeStorage, base: StorageContainer, prefix: string) {
	storage.Container = base
	storage.Prefix = prefix
}

relative_storage_as_container :: proc(storage: ^RelativeStorage) -> StorageContainer {
	if storage == nil { return {} }
	root := storage_join_path(&storage.Container, storage.Prefix)
	return StorageContainer{Root = root, Writable = storage.Container.Writable}
}

content_storage_init :: proc(storage: ^ContentStorage, root: string, writable := false) {
	storage.Container = StorageContainer{Root = root, Writable = writable}
}

content_storage_as_container :: proc(storage: ^ContentStorage) -> ^StorageContainer {
	if storage == nil { return nil }
	return &storage.Container
}

zip_storage_init :: proc(storage: ^ZipStorage, root: string) {
	storage.Container = StorageContainer{Root = root, Writable = false}
	storage.Entries = make(map[string][dynamic]u8)
	data := storage_os_read_file(root, context.temp_allocator)
	if data == nil { return }
	read16 := proc(data: []u8, at: int) -> u16 { return u16(data[at]) | u16(data[at+1])<<8 }
	read32 := proc(data: []u8, at: int) -> u32 { return u32(data[at]) | u32(data[at+1])<<8 | u32(data[at+2])<<16 | u32(data[at+3])<<24 }
	// Locate the end-of-central-directory record from the end of the file.
	eocd := -1
	for i := len(data)-22; i >= 0 && i >= len(data)-65557; i -= 1 {
		if read32(data, i) == 0x06054b50 { eocd = i; break }
	}
	if eocd < 0 { return }
	count := int(read16(data, eocd+10))
	central_offset := int(read32(data, eocd+16))
	for entry := 0; entry < count && central_offset+46 <= len(data); entry += 1 {
		if read32(data, central_offset) != 0x02014b50 { break }
		method := read16(data, central_offset+10)
		compressed_size := int(read32(data, central_offset+20))
		uncompressed_size := int(read32(data, central_offset+24))
		name_size := int(read16(data, central_offset+28))
		extra_size := int(read16(data, central_offset+30))
		comment_size := int(read16(data, central_offset+32))
		local_offset := int(read32(data, central_offset+42))
		if central_offset+46+name_size+extra_size+comment_size > len(data) { break }
		name := string(data[central_offset+46:central_offset+46+name_size])
		if local_offset+30 > len(data) || read32(data, local_offset) != 0x04034b50 { break }
		local_name_size := int(read16(data, local_offset+26))
		local_extra_size := int(read16(data, local_offset+28))
		content_start := local_offset + 30 + local_name_size + local_extra_size
		if content_start < 0 || compressed_size < 0 || content_start+compressed_size > len(data) { break }
		if strings.ends_with(name, "/") { central_offset += 46 + name_size + extra_size + comment_size; continue }
		decoded: [dynamic]u8
		compressed := data[content_start:content_start+compressed_size]
		switch method {
		case 0:
			append(&decoded, ..compressed)
		case 8:
			buffer: bytes.Buffer
			if zlib.inflate_from_byte_array_raw(compressed, &buffer, expected_output_size=uncompressed_size) == nil {
				append(&decoded, ..bytes.buffer_to_bytes(&buffer))
			}
			bytes.buffer_destroy(&buffer)
		}
		if len(decoded) > 0 || uncompressed_size == 0 {
			storage.Entries[name] = decoded
		}
		central_offset += 46 + name_size + extra_size + comment_size
	}
}

zip_storage_as_container :: proc(storage: ^ZipStorage) -> ^StorageContainer {
	if storage == nil { return nil }
	return &storage.Container
}

zip_storage_exists :: proc(storage: ^ZipStorage, path: string) -> bool {
	if storage == nil || storage.Entries == nil { return false }
	_, ok := storage.Entries[path]
	return ok
}

zip_storage_read_all_bytes :: proc(storage: ^ZipStorage, path: string, allocator := context.allocator) -> []byte {
	if storage == nil || storage.Entries == nil { return nil }
	data, ok := storage.Entries[path]
	if !ok { return nil }
	result := make([]byte, len(data), allocator)
	copy(result, data[:])
	return result
}

zip_storage_enumerate_directory :: proc(storage: ^ZipStorage, path: string, allocator := context.allocator) -> []string {
	result := make([dynamic]string, 0, allocator)
	prefix := path
	if prefix != "" && !strings.ends_with(prefix, "/") { prefix, _ = strings.concatenate({prefix, "/"}, context.temp_allocator) }
	for name in storage.Entries {
		if strings.starts_with(name, prefix) { append(&result, name) }
	}
	return result[:]
}

zip_storage_dispose :: proc(storage: ^ZipStorage) {
	if storage == nil { return }
	for _, data in storage.Entries { delete(data) }
	delete(storage.Entries)
	storage.Entries = nil
}

file_system_init :: proc(fs: ^FileSystem, app: ^App) {
	fs.App = app
}

file_system_open_user_storage :: proc(fs: ^FileSystem) -> StorageContainer {
	root := ""
	if fs.App != nil {
		root = fs.App.UserPath
	}
	when ODIN_OS != .JS {
		if root == "" {
			pref_path := SDL.GetPrefPath("", to_cstring(fs.App.Name))
			if pref_path != nil {
				root = string(cstring(pref_path))
			}
		}
		if root != "" {
			_ = storage_os_make_directory_all(root)
		}
	}
	// web: UserPath 恒为虚拟前缀(/foster/<app>/), 由 storage_os_web 落到 localStorage
	return StorageContainer{Root = root, Writable = true}
}

file_system_open_title_storage :: proc(fs: ^FileSystem) -> StorageContainer {
	when ODIN_OS == .JS {
		// web: 无基路径概念(资产内嵌 wasm 或走虚拟 FS), 标题存储指向虚拟 FS 根
		_ = fs
		return StorageContainer{Root = "", Writable = false}
	}
	base_path := SDL.GetBasePath()
	root := ""
	if base_path != nil {
		root = string(base_path)
	}
	if root == "" {
		root = storage_os_working_directory(context.temp_allocator)
	}
	return StorageContainer{Root = root, Writable = false}
}

file_system_open_user_storage_async :: proc(fs: ^FileSystem, callback: proc(storage: StorageContainer)) {
	if callback != nil {
		callback(file_system_open_user_storage(fs))
	}
}

file_system_open_title_storage_async :: proc(fs: ^FileSystem, callback: proc(storage: StorageContainer)) {
	if callback != nil {
		callback(file_system_open_title_storage(fs))
	}
}

file_system_open_file_dialog :: proc(fs: ^FileSystem, title: string, filters: []DialogFilter, callback: DialogCallback) {
	if callback == nil { return }
	request := new(DialogRequest)
	request.Kind = .OpenFiles
	request.FilesCallback = callback
	props := storage_dialog_properties(fs, title, filters, true)
	if props != 0 {
		SDL.ShowFileDialogWithProperties(.OPENFILE, storage_dialog_callback, rawptr(request), props)
		SDL.DestroyProperties(props)
	} else { free(request); callback(DialogResult{Cancelled = true}) }
}

file_system_open_folder_dialog :: proc(fs: ^FileSystem, title: string, callback: DialogCallbackSingleFile) {
	if callback == nil { return }
	request := new(DialogRequest)
	request.Kind = .OpenFolder
	request.SingleCallback = callback
	props := storage_dialog_properties(fs, title, nil, false)
	if props != 0 {
		SDL.ShowFileDialogWithProperties(.OPENFOLDER, storage_dialog_callback, rawptr(request), props)
		SDL.DestroyProperties(props)
	} else { free(request); callback("") }
}

file_system_save_file_dialog :: proc(fs: ^FileSystem, title: string, filters: []DialogFilter, callback: DialogCallbackSingleFile) {
	if callback == nil { return }
	request := new(DialogRequest)
	request.Kind = .SaveFile
	request.SingleCallback = callback
	props := storage_dialog_properties(fs, title, filters, false)
	if props != 0 {
		SDL.ShowFileDialogWithProperties(.SAVEFILE, storage_dialog_callback, rawptr(request), props)
		SDL.DestroyProperties(props)
	} else { free(request); callback("") }
}

open_user_storage :: file_system_open_user_storage
open_title_storage :: file_system_open_title_storage
open_user_storage_async :: file_system_open_user_storage_async
open_title_storage_async :: file_system_open_title_storage_async
open_file_dialog :: file_system_open_file_dialog
open_folder_dialog :: file_system_open_folder_dialog
save_file_dialog :: file_system_save_file_dialog

FileSystemInit :: file_system_init
OpenUserStorage :: file_system_open_user_storage
OpenTitleStorage :: file_system_open_title_storage
OpenUserStorageAsync :: file_system_open_user_storage_async
OpenTitleStorageAsync :: file_system_open_title_storage_async
OpenFileDialog :: file_system_open_file_dialog
OpenFolderDialog :: file_system_open_folder_dialog
SaveFileDialog :: file_system_save_file_dialog

Exists :: storage_exists
FileExists :: storage_file_exists
DirectoryExists :: storage_directory_exists
EnumerateDirectory :: storage_enumerate_directory
CreateDirectory :: storage_create_directory
Remove :: storage_remove
ReadAllBytes :: storage_read_all_bytes
ReadAllText :: storage_read_all_text
WriteAllBytes :: storage_write_all_bytes
WriteAllText :: storage_write_all_text
DisposeStorage :: storage_dispose

DirectoryStorageInit :: directory_storage_init
DirectoryStorageContainer :: directory_storage_as_container
RelativeStorageInit :: relative_storage_init
RelativeStorageContainer :: relative_storage_as_container
ContentStorageInit :: content_storage_init
ContentStorageContainer :: content_storage_as_container
ZipStorageInit :: zip_storage_init
ZipStorageContainer :: zip_storage_as_container
ZipStorageExists :: zip_storage_exists
ZipStorageReadAllBytes :: zip_storage_read_all_bytes
ZipStorageEnumerateDirectory :: zip_storage_enumerate_directory
ZipStorageDispose :: zip_storage_dispose

StorageDebugString :: proc(container: ^StorageContainer) -> string {
	return fmt.aprintf("StorageContainer{root=%q, writable=%v}", container.Root, container.Writable)
}
